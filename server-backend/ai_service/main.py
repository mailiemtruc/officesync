import uvicorn
import httpx
import datetime
import logging
from typing import Optional
from contextlib import asynccontextmanager
from fastapi import FastAPI
from pydantic import BaseModel
from pydantic_settings import BaseSettings, SettingsConfigDict
import google.generativeai as genai

# Import Manager
from tool_manager import manager
# Import service ngôn ngữ để đọc bộ nhớ
import services.language as lang_service 

# --- CẤU HÌNH ---
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class Settings(BaseSettings):
    GOOGLE_API_KEY: str
    ATTENDANCE_SERVICE_URL: str
    
    # Cấu hình Pydantic v2
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

settings = Settings()
genai.configure(api_key=settings.GOOGLE_API_KEY)

# --- LIFESPAN (HTTP CLIENT) ---
http_client: Optional[httpx.AsyncClient] = None

@asynccontextmanager
async def lifespan(app: FastAPI):
    global http_client
    http_client = httpx.AsyncClient(timeout=10.0)
    yield
    await http_client.aclose()

app = FastAPI(lifespan=lifespan)

# --- CHAT ENDPOINT ---
class ChatRequest(BaseModel):
    userId: int
    message: str

@app.post("/chat")
async def chat_endpoint(req: ChatRequest):
    try:
        # 1. Context cơ bản
        today = datetime.date.today()
        service_instructions = manager.get_combined_prompts()

        # --- [LOGIC MỚI] KIỂM TRA NGÔN NGỮ & ĐIỀU CHỈNH THÁI ĐỘ ---
        user_lang = lang_service.USER_PREFERENCES.get(req.userId)
        
        # [QUAN TRỌNG] Định nghĩa quy tắc lịch sự chung (áp dụng cho mọi trường hợp)
        common_rules = """
        QUY TẮC ỨNG XỬ (TONE & VOICE):
        1. Thái độ: Lễ phép, Nhẹ nhàng, Chuyên nghiệp (Như lễ tân khách sạn 5 sao).
        2. ANTI-ROBOT: 
           - TUYỆT ĐỐI KHÔNG bắt đầu câu bằng "OK", "Ok", "Okay". 
           - Thay vào đó hãy dùng: "Dạ vâng", "Vâng", "Thưa bạn", "Certainly", "Sure", "Understood".
        """

        if not user_lang:
            # TRƯỜNG HỢP 1: Chưa chọn -> Hướng dẫn Bot NHẬN DIỆN và XÁC NHẬN ĐÚNG NGÔN NGỮ
            lang_instruction = f"""
            ⚠️ TRẠNG THÁI: Người dùng MỚI (chưa thiết lập ngôn ngữ).
            {common_rules}
            
            NHIỆM VỤ ƯU TIÊN SỐ 1: Xác định ngôn ngữ để gọi tool `set_language`.

            KỊCH BẢN HÀNH ĐỘNG:
            1. Nếu nhận được tín hiệu "START_CONVERSATION":
               -> Chào và hỏi: "Bạn muốn giao tiếp bằng English hay Tiếng Việt?".
            
            2. Nếu người dùng trả lời (VD: "English", "vn", "Tiếng Việt"...):
               -> ĐỪNG hỏi lại.
               -> GỌI NGAY tool `set_language` với tham số tương ứng.
               -> QUAN TRỌNG: Sau khi gọi tool xong, hãy xác nhận bằng NGÔN NGỮ VỪA CHỌN.
                  (Ví dụ: Nếu chọn Tiếng Việt -> "Vâng, tôi đã ghi nhận lựa chọn của bạn."; Nếu chọn English -> "Certainly! I have saved your preference.").
            """
        else:
            # TRƯỜNG HỢP 2: Đã chọn -> Thiết lập nhân cách chuyên nghiệp
            # Chỉ giữ lại greeting_guide, XÓA switch_confirm cứng
            if user_lang == "Vietnamese":
                greeting_guide = 'Hãy nói: "Xin chào! Chào mừng bạn quay trở lại OfficeSync. Tôi có thể hỗ trợ gì cho công việc của bạn hôm nay?"'
            else:
                greeting_guide = 'Say: "Welcome back to OfficeSync! How can I assist you with your work today?"'

            lang_instruction = f"""
            ✅ TRẠNG THÁI: Người dùng ĐÃ CHỌN ngôn ngữ là {user_lang}.
            {common_rules}
            
            QUY TẮC RIÊNG:
            1. Ngôn ngữ hiện tại: {user_lang}.
            
            KỊCH BẢN CỤ THỂ:
            1. Nếu người dùng yêu cầu đổi ngôn ngữ (VD: "Switch to Vietnamese", "Đổi sang tiếng Việt"):
               -> Gọi Tool `set_language`.
               -> QUAN TRỌNG: Sau khi gọi tool xong, hãy xác nhận bằng NGÔN NGỮ MỚI vừa chọn.
               (Ví dụ: Nếu vừa chuyển sang Vietnamese -> Nói: "Dạ vâng, tôi đã chuyển sang Tiếng Việt..."; Nếu chuyển sang English -> Nói: "Certainly! I have switched to English...").
            
            2. Nếu nhận được tín hiệu "START_CONVERSATION":
               -> {greeting_guide}
            """

        # 2. System Prompt
        full_system_instruction = f"""
        Thời gian hiện tại: {today.strftime('%Y-%m-%d')}.
        Bạn là trợ lý ảo OfficeSync. UserID hiện tại: {req.userId}.
        
        --- ĐIỀU KHIỂN NGÔN NGỮ ---
        {lang_instruction}
        
        --- HƯỚNG DẪN NGHIỆP VỤ ---
        Nhiệm vụ: Hỗ trợ nhân viên tra cứu thông tin nội bộ.
        {service_instructions}
        """

        # 3. Khởi tạo Model
        model = genai.GenerativeModel(
            'gemini-2.0-flash', 
            tools=manager.tools_schema,
            system_instruction=full_system_instruction 
        )

        chat = model.start_chat(enable_automatic_function_calling=False)

        # 4. Gửi tin nhắn User
        response = await chat.send_message_async(req.message)

        # 5. Xử lý Tool Calling
        if response.candidates and response.candidates[0].content.parts:
            for part in response.candidates[0].content.parts:
                
                # Nếu tìm thấy yêu cầu gọi hàm
                if part.function_call:
                    fc = part.function_call
                    tool_name = fc.name
                    args = {k: v for k, v in fc.args.items()}
                    
                    logger.info(f"🤖 Tool Call Found: {tool_name} | Args: {args}")

                    # Gọi ToolManager
                    tool_result = await manager.handle_tool_call(
                        tool_name, req.userId, args, http_client, settings
                    )
                    
                    # Trả kết quả về Gemini
                    final_res = await chat.send_message_async(
                        genai.protos.Content(
                            parts=[genai.protos.Part(
                                function_response=genai.protos.FunctionResponse(
                                    name=tool_name,
                                    response={"result": tool_result}
                                )
                            )]
                        )
                    )
                    
                    # [AN TOÀN]
                    try:
                        return {"reply": final_res.text}
                    except ValueError:
                        return {"reply": "Đã thực hiện lệnh nhưng AI không trả lời bằng văn bản."}

        # 6. Trả về câu trả lời thường
        try:
            return {"reply": response.text}
        except ValueError:
            logger.warning("⚠️ Response contains non-text parts but no tool was handled.")
            return {"reply": "Hệ thống đang xử lý, vui lòng thử lại cụ thể hơn."}

    except Exception as e:
        logger.error(f"Error: {e}", exc_info=True)
        return {"reply": "Xin lỗi, hệ thống đang gặp sự cố gián đoạn."}

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=5000, reload=True)