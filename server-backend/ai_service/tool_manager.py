# [FILE: tool_manager.py]
import services.attendance as attendance
import services.language as language

class ToolManager:
    def __init__(self):
        self.tools_schema = [] 
        self.handlers = {}     
        self.prompts = []

    def register(self, module):
        """Đăng ký module hỗ trợ nhiều functions"""
        
        # 1. Thêm schema (Gộp danh sách function_declarations)
        if hasattr(module, 'TOOL_DEF'):
            # Google GenAI yêu cầu format: tools=[{function_declarations: [...]}]
            # Nên ta sẽ merge các declaration vào list chung hoặc append nguyên block
            # Ở đây ta chọn cách append nguyên block Tool Def
            self.tools_schema.append(module.TOOL_DEF)

            # 2. Map tên hàm -> logic thực thi
            # [SỬA ĐỔI] Duyệt qua tất cả function trong module
            funcs = module.TOOL_DEF.get('function_declarations', [])
            for f in funcs:
                func_name = f['name']
                # Lưu handler là hàm execute của module
                self.handlers[func_name] = module.execute

        # 3. Đăng ký Prompt
        if hasattr(module, 'SYSTEM_PROMPT'):
            self.prompts.append(module.SYSTEM_PROMPT)

    def get_combined_prompts(self):
        return "\n".join(self.prompts)

    async def handle_tool_call(self, tool_name, user_id, args, client, settings):
        handler = self.handlers.get(tool_name)
        if handler:
            # [SỬA ĐỔI] Truyền thêm tool_name để module biết gọi hàm nào
            return await handler(user_id, args, client, settings, tool_name=tool_name)
        return "Lỗi: Tool này chưa được hỗ trợ."

manager = ToolManager()
manager.register(attendance)
manager.register(language)