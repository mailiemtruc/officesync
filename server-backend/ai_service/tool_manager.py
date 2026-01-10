import services.attendance as attendance
import services.language as language

class ToolManager:
    def __init__(self):
        self.tools_schema = [] # Danh sách schema gửi cho Gemini
        self.handlers = {}     # Map tên hàm -> logic thực thi
        self.prompts = []      # [MỚI] Danh sách các hướng dẫn từ service

    def register(self, module):
        """Đăng ký một service module"""
        # 1. Thêm schema
        self.tools_schema.append(module.TOOL_DEF)
        
        # 2. Map tên hàm
        func_name = module.TOOL_DEF['function_declarations'][0]['name']
        self.handlers[func_name] = module.execute

        # 3. [MỚI] Đăng ký Prompt riêng (nếu có)
        if hasattr(module, 'SYSTEM_PROMPT'):
            self.prompts.append(module.SYSTEM_PROMPT)

    def get_combined_prompts(self):
        """[MỚI] Gộp tất cả hướng dẫn thành 1 chuỗi"""
        return "\n".join(self.prompts)

    async def handle_tool_call(self, tool_name, user_id, args, client, settings):
        """Tìm handler và chạy"""
        handler = self.handlers.get(tool_name)
        if handler:
            return await handler(user_id, args, client, settings)
        return "Lỗi: Tool này chưa được hỗ trợ."

# Khởi tạo singleton manager
manager = ToolManager()

# ĐĂNG KÝ CÁC SERVICE Ở ĐÂY
manager.register(attendance)
manager.register(language)