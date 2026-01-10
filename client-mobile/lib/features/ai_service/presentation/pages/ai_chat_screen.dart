import 'package:flutter/material.dart';
import '../../../../core/config/app_colors.dart'; // Giữ nguyên import của bạn
import '../../data/ai_api.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AiApi _aiApi = AiApi();

  // [SỬA 1] Bắt đầu với danh sách rỗng (để chờ Server trả lời)
  final List<Map<String, dynamic>> _messages = [];

  bool _isTyping = false;

  // Gợi ý câu hỏi nhanh
  final List<String> _suggestions = [
    "Tháng này tôi chấm công thế nào?",
    "Hôm nay tôi đã check-in chưa?",
    "Lịch sử đi muộn tháng trước?",
  ];

  // [SỬA 2] Gọi hàm khởi tạo hội thoại ngay khi vào màn hình
  @override
  void initState() {
    super.initState();
    _startConversation();
  }

  // [SỬA 3] Hàm gửi tin nhắn mở đầu (User không thấy tin mình gửi, chỉ thấy AI rep)
  void _startConversation() async {
    setState(() {
      _isTyping = true; // Hiện 3 chấm loading ngay lập tức
    });

    // Gửi tín hiệu ngầm lên Server
    // Server Python sẽ nhận chuỗi này -> Kiểm tra user chưa chọn ngôn ngữ -> Hỏi lại
    String reply = await _aiApi.sendMessage("START_CONVERSATION");

    if (mounted) {
      setState(() {
        _isTyping = false;
        // Thêm câu trả lời của AI vào list
        _messages.add({"isUser": false, "text": reply});
      });
    }
  }

  void _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    // 1. Hiển thị tin nhắn của User
    setState(() {
      _messages.add({"isUser": true, "text": text});
      _isTyping = true;
    });
    _controller.clear();
    _scrollToBottom();

    // 2. Gọi API
    String reply = await _aiApi.sendMessage(text);

    // 3. Hiển thị câu trả lời của AI
    if (mounted) {
      setState(() {
        _isTyping = false;
        _messages.add({"isUser": false, "text": reply});
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // --- HEADER ---
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.smart_toy_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  "AI Assistant",
                  style: TextStyle(
                    color: Color(0xFF1E293B),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  "Online",
                  style: TextStyle(color: Colors.green, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),

      body: Column(
        children: [
          // 1. DANH SÁCH TIN NHẮN
          Expanded(
            child: _messages.isEmpty && !_isTyping
                ? const Center(
                    child: Text("Bắt đầu trò chuyện..."),
                  ) // Placeholder nếu chưa có gì
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_isTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length && _isTyping) {
                        return _buildTypingIndicator();
                      }
                      final msg = _messages[index];
                      return _buildMessageBubble(msg['text'], msg['isUser']);
                    },
                  ),
          ),

          // 2. GỢI Ý NHANH (Ẩn khi chưa load xong tin nhắn đầu)
          if (_messages.isNotEmpty && _messages.length < 5)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: _suggestions
                    .map(
                      (s) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          label: Text(
                            s,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                            ),
                          ),
                          backgroundColor: AppColors.primary.withOpacity(0.05),
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          onPressed: () => _sendMessage(s),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),

          // 3. KHUNG NHẬP LIỆU (Giữ nguyên)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _controller,
                        decoration: const InputDecoration(
                          hintText: "Hỏi tôi về chấm công...",
                          border: InputBorder.none,
                          hintStyle: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                        onSubmitted: _sendMessage,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => _sendMessage(_controller.text),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // (Giữ nguyên các widget UI _buildMessageBubble và _buildTypingIndicator)
  Widget _buildMessageBubble(String text, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primary : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isUser ? const Radius.circular(16) : Radius.zero,
            bottomRight: isUser ? Radius.zero : const Radius.circular(16),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isUser ? Colors.white : const Color(0xFF1E293B),
            fontSize: 15,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: Color(0xFFF1F5F9),
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        child: SizedBox(
          width: 40,
          height: 20,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: const [
              CircleAvatar(radius: 3, backgroundColor: Colors.grey),
              CircleAvatar(radius: 3, backgroundColor: Colors.grey),
              CircleAvatar(radius: 3, backgroundColor: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
