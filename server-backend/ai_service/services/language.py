# services/language.py
import logging

logger = logging.getLogger(__name__)

# --- BỘ NHỚ TẠM (RAM) ---
# Lưu mapping: {user_id: "Vietnamese"}
# Lưu ý: Khi tắt server dữ liệu này sẽ mất (cần Database nếu muốn lưu lâu dài)
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
async def execute(user_id: int, args: dict, client, settings) -> str:
    lang = args.get("language")
    USER_PREFERENCES[user_id] = lang
    
    if lang == "Vietnamese":
        return "Đã ghi nhận: Tiếng Việt. Từ giờ tôi sẽ trả lời bằng Tiếng Việt."
    else:
        return "Language set to English. I will respond in English from now on."

# --- 3. SYSTEM PROMPT RIÊNG (Không bắt buộc vì ta sẽ xử lý ở main) ---
SYSTEM_PROMPT = ""