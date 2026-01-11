# services/language.py
import logging

logger = logging.getLogger(__name__)

# --- BỘ NHỚ TẠM (RAM) ---
USER_PREFERENCES = {}

# --- 1. SCHEMA ---
TOOL_DEF = {
    "function_declarations": [{
        "name": "set_language",
        "description": "Lưu lại ngôn ngữ giao tiếp mà người dùng đã chọn.",
        "parameters": {
            "type": "object",
            "properties": {
                "language": {
                    "type": "string",
                    "enum": ["Vietnamese", "English"],
                    "description": "Ngôn ngữ người dùng chọn."
                }
            },
            "required": ["language"]
        }
    }]
}

# --- 2. LOGIC ---
# [SỬA LỖI] Thêm tham số tool_name=None để khớp với ToolManager mới
async def execute(user_id: int, args: dict, client, settings, tool_name: str = None) -> str:
    lang = args.get("language")
    USER_PREFERENCES[user_id] = lang
    
    # Log để debug xem đã lưu chưa
    logger.info(f"User {user_id} set language to: {lang}")

    if lang == "Vietnamese":
        return "Đã ghi nhận: Tiếng Việt. Từ giờ tôi sẽ trả lời bằng Tiếng Việt."
    else:
        return "Language set to English. I will respond in English from now on."

# --- 3. SYSTEM PROMPT RIÊNG ---
SYSTEM_PROMPT = ""