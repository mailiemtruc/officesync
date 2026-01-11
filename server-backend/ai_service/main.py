import uvicorn
import httpx
import datetime
import logging
from typing import Optional, Dict, List
from contextlib import asynccontextmanager
from fastapi import FastAPI
from pydantic import BaseModel
from pydantic_settings import BaseSettings, SettingsConfigDict
import google.generativeai as genai

# Import Manager
from tool_manager import manager
# Import service ngôn ngữ
import services.language as lang_service 

# --- CẤU HÌNH ---
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class Settings(BaseSettings):
    GOOGLE_API_KEY: str
    ATTENDANCE_SERVICE_URL: str
    
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

settings = Settings()
genai.configure(api_key=settings.GOOGLE_API_KEY)

# --- BỘ NHỚ CHAT (RAM) ---
CHAT_HISTORY: Dict[int, List] = {}

# --- LIFESPAN ---
http_client: Optional[httpx.AsyncClient] = None

@asynccontextmanager
async def lifespan(app: FastAPI):
    global http_client
    http_client = httpx.AsyncClient(timeout=30.0)
    yield
    await http_client.aclose()

app = FastAPI(lifespan=lifespan)

class ChatRequest(BaseModel):
    userId: int
    message: str

@app.post("/chat")
async def chat_endpoint(req: ChatRequest):
    try:
        # 1. Context cơ bản
        today = datetime.date.today()
        service_instructions = manager.get_combined_prompts()
        user_lang = lang_service.USER_PREFERENCES.get(req.userId)
        
        common_rules = """
        QUY TẮC ỨNG XỬ:
        1. Thái độ: Lễ phép, Nhẹ nhàng, Chuyên nghiệp.
        2. ANTI-ROBOT: KHÔNG bắt đầu bằng "OK", "Ok". Dùng "Dạ vâng", "Vâng", "Thưa bạn".
        """

        if not user_lang:
            lang_instruction = f"""
            ⚠️ TRẠNG THÁI: Người dùng MỚI (Chưa lưu thiết lập ngôn ngữ).
            {common_rules}
            
            NHIỆM VỤ: Tự động nhận diện và lưu ngôn ngữ.

            KỊCH BẢN HÀNH ĐỘNG:
            1. Nếu User CHÀO hoặc nói "START_CONVERSATION":
               -> Hỏi lịch sự: "Bạn muốn giao tiếp bằng English hay Tiếng Việt?".
            
            2. Nếu User HỎI THẲNG vào nghiệp vụ (VD: "Chấm công chưa?", "Attendance history", "Tôi đi trễ không"):
               -> BƯỚC 1: Phân tích ngôn ngữ User đang dùng (Vietnamese hay English).
               -> BƯỚC 2: GỌI NGAY tool `set_language` với ngôn ngữ đó. (QUAN TRỌNG: Phải gọi tool này để hệ thống ghi nhớ).
               -> BƯỚC 3: Sau đó mới gọi tiếp các tool chấm công để trả lời câu hỏi.
               -> LƯU Ý: Không cần thông báo "Đã lưu ngôn ngữ", hãy trả lời thẳng vào câu hỏi của User.
            
            3. Nếu User nói tên ngôn ngữ (VD: "Tiếng Việt", "vn", "English"):
               -> Gọi `set_language` và xác nhận.
            """
        else:
            if user_lang == "Vietnamese":
                greeting_guide = 'Hãy nói: "Xin chào! Chào mừng bạn quay trở lại OfficeSync. Tôi có thể hỗ trợ gì cho công việc của bạn hôm nay?"'
            else:
                greeting_guide = 'Say: "Welcome back to OfficeSync! How can I assist you with your work today?"'

            lang_instruction = f"""
            ✅ TRẠNG THÁI: Ngôn ngữ {user_lang}.
            {common_rules}
            KỊCH BẢN:
            - Nếu User chào hoặc nói "START_CONVERSATION" -> {greeting_guide}
            - Nếu User đang trả lời câu hỏi trước đó (Ví dụ: "Có", "Không", "Chi tiết đi") -> HÃY TIẾP TỤC MẠCH TRUYỆN, ĐỪNG CHÀO LẠI.
            """

        # 2. System Prompt
        full_system_instruction = f"""
        Thời gian hiện tại: {today.strftime('%Y-%m-%d')}.
        Bạn là trợ lý ảo OfficeSync.
        
        {lang_instruction}
        
        --- HƯỚNG DẪN NGHIỆP VỤ ---
        {service_instructions}
        """

        # 3. Khởi tạo Model
        model = genai.GenerativeModel(
            'gemini-2.0-flash', 
            tools=manager.tools_schema,
            system_instruction=full_system_instruction 
        )

        user_history = CHAT_HISTORY.get(req.userId, [])
        chat = model.start_chat(history=user_history, enable_automatic_function_calling=False)

        # 4. Gửi tin nhắn User
        response = await chat.send_message_async(req.message)

        # --- [SỬA ĐỔI QUAN TRỌNG] VÒNG LẶP XỬ LÝ TOOL ---
        # Dùng vòng lặp để xử lý trường hợp Gemini gọi nhiều tool liên tiếp
        # (VD: set_language -> Xong -> get_attendance -> Xong -> Trả lời text)
        
        final_text = ""
        
        while True:
            function_call_part = None
            if response.candidates and response.candidates[0].content.parts:
                for part in response.candidates[0].content.parts:
                    if part.function_call:
                        function_call_part = part
                        break
            
            if function_call_part:
                # --- CÓ GỌI TOOL ---
                fc = function_call_part.function_call
                tool_name = fc.name
                args = {k: v for k, v in fc.args.items()}
                
                logger.info(f"🤖 Tool Call: {tool_name} | Args: {args}")

                # Thực thi tool
                tool_result = await manager.handle_tool_call(
                    tool_name, req.userId, args, http_client, settings
                )
                
                # Gửi kết quả lại cho Gemini và NHẬN RESPONSE MỚI
                response = await chat.send_message_async(
                    genai.protos.Content(
                        parts=[genai.protos.Part(
                            function_response=genai.protos.FunctionResponse(
                                name=tool_name,
                                response={"result": tool_result}
                            )
                        )]
                    )
                )
                # Tiếp tục vòng lặp để kiểm tra xem response mới có gọi tool tiếp không
                continue 
            else:
                # --- KHÔNG GỌI TOOL (Là Text) ---
                final_text = response.text
                break # Thoát vòng lặp

        # 6. Lưu lịch sử
        CHAT_HISTORY[req.userId] = chat.history

        return {"reply": final_text}

    except Exception as e:
        logger.error(f"Error: {e}", exc_info=True)
        return {"reply": "Xin lỗi, hệ thống đang gặp sự cố gián đoạn."}

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=5000, reload=True)