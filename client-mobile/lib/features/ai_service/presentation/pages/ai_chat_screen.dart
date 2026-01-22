import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:shimmer/shimmer.dart'; // <-- Bỏ dòng này vì đã chuyển logic sang file khác
import '../../../../core/config/app_colors.dart';
import '../../data/ai_api.dart';

// 1. IMPORT WIDGET DÙNG CHUNG (Chú ý đường dẫn)
import '../../widgets/skeleton_chat_bubble.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AiApi _aiApi = AiApi();

  // Color Palette
  static const Color primaryColor = Color(0xFF2260FF);
  static const Color primaryDark = Color(0xFF1A4BD6);
  static const Color bgChatColor = Color(0xFFF8FAFC);
  static const Color textDark = Color(0xFF1E293B);

  final List<Map<String, dynamic>> _messages = [];
  bool _isTyping = false;

  final List<String> _suggestions = [
    "Tháng này công cán sao?",
    "Hôm nay check-in chưa?",
    "Lịch sử đi muộn?",
  ];

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
    _startConversation();
  }

  void _startConversation() async {
    setState(() => _isTyping = true);
    String reply = await _aiApi.sendMessage("START_CONVERSATION");

    if (mounted) {
      setState(() {
        _isTyping = false;
        _messages.add({"isUser": false, "text": reply});
      });
    }
  }

  void _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add({"isUser": true, "text": text});
      _isTyping = true;
    });
    _controller.clear();
    _scrollToBottom();

    String reply = await _aiApi.sendMessage(text);

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
          _scrollController.position.maxScrollExtent + 60,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutQuad,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgChatColor,
      appBar: _buildModernAppBar(),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                // 2. SỬ DỤNG WIDGET DÙNG CHUNG TẠI ĐÂY
                if (index == _messages.length && _isTyping) {
                  return const SkeletonChatBubble(); // <-- Đổi tên thành SkeletonChatBubble
                }

                final msg = _messages[index];
                return ModernMessageBubble(
                  text: msg['text'],
                  isUser: msg['isUser'],
                );
              },
            ),
          ),
          if (_messages.isNotEmpty && _messages.length < 4)
            Container(
              height: 50,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: _suggestions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  return ActionChip(
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    label: Text(
                      _suggestions[index],
                      style: const TextStyle(
                        fontSize: 13,
                        color: primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    backgroundColor: primaryColor.withOpacity(0.08),
                    side: BorderSide(color: primaryColor.withOpacity(0.1)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    onPressed: () => _sendMessage(_suggestions[index]),
                  );
                },
              ),
            ),
          _buildFloatingInput(),
        ],
      ),
    );
  }

  // ... (Phần _buildModernAppBar và _buildFloatingInput giữ nguyên như cũ)
  PreferredSizeWidget _buildModernAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: textDark, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.smart_toy_rounded,
                  color: primaryColor,
                  size: 24,
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                "OfficeSync AI",
                style: TextStyle(
                  color: textDark,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                "Always Active",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: Colors.grey.withOpacity(0.1), height: 1),
      ),
    );
  }

  Widget _buildFloatingInput() {
    return Container(
      color: bgChatColor,
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 24, top: 8),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        style: const TextStyle(fontSize: 15),
                        decoration: const InputDecoration(
                          hintText: "Ask me anything...",
                          hintStyle: TextStyle(color: Colors.grey),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 14),
                        ),
                        onSubmitted: _sendMessage,
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => _sendMessage(_controller.text),
              child: Container(
                width: 50,
                height: 50,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [primaryColor, primaryDark]),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x402260FF),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ModernMessageBubble extends StatelessWidget {
  final String text;
  final bool isUser;

  const ModernMessageBubble({
    super.key,
    required this.text,
    required this.isUser,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          gradient: isUser
              ? const LinearGradient(
                  colors: [Color(0xFF2260FF), Color(0xFF1650E6)],
                )
              : null,
          color: isUser ? null : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: isUser
                ? const Radius.circular(20)
                : const Radius.circular(4),
            bottomRight: isUser
                ? const Radius.circular(4)
                : const Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isUser ? Colors.white : const Color(0xFF334155),
            fontSize: 15,
            height: 1.5,
            fontWeight: isUser ? FontWeight.w500 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
