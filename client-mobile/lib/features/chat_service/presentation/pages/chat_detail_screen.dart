import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:stomp_dart_client/stomp.dart';
import 'package:stomp_dart_client/stomp_config.dart';
import 'package:stomp_dart_client/stomp_frame.dart';
import 'package:intl/intl.dart';
// Import các file trong project
import '../../data/models/chat_message.dart';
import '../../data/chat_api.dart';
import '../../widgets/message_bubble.dart';
import 'dart:io'; // [MỚI]
import 'package:image_picker/image_picker.dart'; // [MỚI]
import '../../presentation/pages/storage_service.dart'; // [MỚI] Nhớ tạo file này trước nhé
import 'chat_info_screen.dart';

class ChatDetailScreen extends StatefulWidget {
  final int roomId;
  final String chatName;
  final String? avatarUrl;
  final String? partnerId;
  final bool initIsOnline;

  const ChatDetailScreen({
    Key? key,
    required this.roomId,
    required this.chatName,
    this.avatarUrl,
    this.partnerId, // ID người kia (dùng để check status)
    this.initIsOnline = false, // Trạng thái ban đầu
  }) : super(key: key);

  @override
  _ChatDetailScreenState createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final ChatApi _chatApi = ChatApi();
  final _storage = const FlutterSecureStorage();
  // [MỚI] Khai báo Service Upload và Picker
  final StorageService _storageService = StorageService();
  final ImagePicker _picker = ImagePicker();

  StompClient? stompClient;
  List<ChatMessage> messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String myId = "";
  bool isConnected = false;
  bool isLoadingHistory = true;
  bool isPartnerOnline = false;

  @override
  void initState() {
    super.initState();
    isPartnerOnline = widget.initIsOnline;
    _initChat();
  }

  @override
  void dispose() {
    stompClient?.deactivate();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _initChat() async {
    String? id = await _storage.read(key: 'userId');
    if (id != null) {
      setState(() => myId = id);
      _connectSocket();
      _loadHistory();
      _fetchInitialRoomStatus();
    }
  }

  // 1. Load lịch sử tin nhắn
  void _loadHistory() async {
    try {
      final history = await _chatApi.fetchMessagesByRoom(widget.roomId);
      // Đảo ngược vì ListView đang reverse: true
      final reversedHistory = history.reversed.toList();

      if (mounted) {
        setState(() {
          messages = reversedHistory;
          isLoadingHistory = false;
        });
      }
    } catch (e) {
      print("Lỗi load history: $e");
      if (mounted) setState(() => isLoadingHistory = false);
    }
  }

  // 2. Kết nối WebSocket
  void _connectSocket() async {
    String? token = await _storage.read(key: 'auth_token');
    if (token == null) return;

    stompClient = StompClient(
      config: StompConfig(
        url: ChatApi.wsUrl,
        onConnect: (frame) {
          print("✅ Đã kết nối vào phòng: ${widget.roomId}");
          if (mounted) setState(() => isConnected = true);
          _subscribeToRoom();
          _subscribeToStatus();
        },
        onWebSocketError: (err) => print("❌ Lỗi Socket: $err"),
        onStompError: (frame) => print("❌ Lỗi Stomp: ${frame.body}"),
        stompConnectHeaders: {'Authorization': 'Bearer $token'},
        webSocketConnectHeaders: {'Authorization': 'Bearer $token'},
      ),
    );
    stompClient!.activate();
  }

  void _subscribeToStatus() {
    // Nếu chat nhóm hoặc không có ID đối phương thì thôi
    if (widget.partnerId == null) return;

    stompClient!.subscribe(
      destination: '/topic/status', // Kênh chung bắn status
      callback: (StompFrame frame) {
        if (frame.body != null) {
          final data = json.decode(frame.body!);
          // Kiểm tra xem status này có phải của người mình đang chat không
          if (data['id'].toString() == widget.partnerId.toString()) {
            if (mounted) {
              setState(() {
                isPartnerOnline = data['isOnline'] ?? false;
              });
            }
          }
        }
      },
    );
  }

  // 3. Đăng ký nhận tin (Đã sửa lỗi đóng ngoặc)
  void _subscribeToRoom() {
    stompClient!.subscribe(
      destination: '/topic/room/${widget.roomId}',
      callback: (StompFrame frame) {
        if (frame.body != null) {
          final data = json.decode(frame.body!);

          // 1. Parse tin nhắn từ Server
          // Lưu ý: Đảm bảo Model ChatMessage của bạn xử lý tốt việc ID là số hay chuỗi
          ChatMessage serverMsg = ChatMessage.fromJson(data, myId);

          // Log để kiểm tra (Xem trong Console)
          print(
            "📩 Socket nhận: ${serverMsg.content} - Sender: ${data['senderId']}",
          );

          if (mounted) {
            setState(() {
              // 2. LOGIC CHỐNG TRÙNG LẶP (Dùng indexWhere an toàn hơn)
              // Tìm trong danh sách xem có tin nhắn nào "của mình" (isMe)
              // VÀ nội dung giống hệt tin vừa nhận không?
              int index = messages.indexWhere(
                (msg) => msg.isMe == true && msg.content == serverMsg.content,
              );

              if (index != -1) {
                // => Đã tìm thấy tin nhắn ảo trước đó!
                print(
                  "♻️ Phát hiện trùng lặp tại index $index -> Cập nhật thay vì thêm mới.",
                );

                // Cập nhật lại tin đó với dữ liệu chuẩn từ server (ID thật, giờ thật...)
                // Ép cứng isMe = true để đảm bảo nó vẫn nằm bên phải
                messages[index] = serverMsg.copyWith(isMe: true);
              } else {
                // => Không tìm thấy (Tin mới hoặc tin của người khác)
                print("➕ Thêm tin nhắn mới.");
                messages.insert(0, serverMsg);
              }
            });
          }
        }
      },
    );
  }

  // 4. Gửi tin nhắn (Hiện ngay lập tức)
  void _doPostMessage(String content, {String type = 'CHAT'}) {
    // 1. Tạo tin nhắn giả để hiện ngay (Optimistic UI)
    final tempMsg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: myId,
      content: content,
      timestamp: DateTime.now().toIso8601String(),
      isMe: true,
      senderName: "Me",
      avatarUrl: "",
      recipientId: '',
      type:
          type, // [QUAN TRỌNG] Truyền type vào Model (Cần sửa Model ChatMessage để nhận field này)
    );

    setState(() {
      messages.insert(0, tempMsg);
    });

    // 2. Gửi thật lên Server
    if (stompClient != null && stompClient!.connected) {
      stompClient!.send(
        destination: '/app/chat.sendMessage',
        body: json.encode({
          'roomId': widget.roomId,
          'content': content,
          'recipientId': "0",
          'type': type, // [QUAN TRỌNG] Gửi type lên Server
        }),
      );
    } else {
      print("❌ Mất kết nối Socket");
    }
  }

  // [HÀM CŨ ĐƯỢC SỬA] Chỉ xử lý việc lấy text từ ô nhập liệu
  void _handleTextSubmit() {
    if (_controller.text.trim().isEmpty) return;
    final text = _controller.text.trim();
    _controller.clear();
    _doPostMessage(text, type: 'CHAT'); // Gọi hàm chung
  }

  // [HÀM MỚI] Chọn ảnh và Upload
  void _pickAndSendImage() async {
    // 1. Mở thư viện ảnh
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      print("📸 Đang upload ảnh...");
      // Có thể hiện Loading Indicator ở đây nếu muốn

      // 2. Upload
      File file = File(image.path);
      String? imageUrl = await _storageService.uploadImage(file);

      if (imageUrl != null) {
        print("✅ Upload xong: $imageUrl");
        // 3. Gửi tin nhắn dạng IMAGE
        _doPostMessage(imageUrl, type: 'IMAGE');
      } else {
        print("❌ Upload thất bại");
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Image upload failed")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: NetworkImage(
                widget.avatarUrl ??
                    "https://ui-avatars.com/api/?name=${Uri.encodeComponent(widget.chatName)}&background=random",
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.chatName,
                    style: const TextStyle(
                      color: Color(0xFF2260FF),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  (!isConnected || isPartnerOnline)
                      ? Text(
                          !isConnected ? "Connecting..." : "Online",
                          style: TextStyle(
                            color: !isConnected
                                ? Colors.grey
                                : Colors.green, // Online màu xanh
                            fontSize: 12,
                          ),
                        )
                      : const SizedBox(), // Nếu Offline thì ẩn luôn, không chiếm chỗ
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline), // Icon chữ 'i'
            color: const Color(0xFF2260FF), // Màu xanh
            onPressed: () {
              // Kiểm tra xem đây là nhóm hay chat riêng
              // Nếu partnerId == null thì coi như là Group (hoặc logic tùy bạn chỉnh)
              bool isGroupChat = (widget.partnerId == null);

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatInfoScreen(
                    roomId: widget.roomId,
                    isGroup: isGroupChat,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: isLoadingHistory
                ? const Center(child: CircularProgressIndicator())
                : messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    reverse: true, // Tin mới nhất ở dưới cùng (Index 0)
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 20,
                    ),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];

                      // 1. Logic ẩn Avatar (Giữ nguyên code cũ của bạn)
                      bool showAvatar = true;
                      if (index > 0) {
                        final newerMsg =
                            messages[index -
                                1]; // Tin nhắn mới hơn (nằm ngay dưới về mặt hiển thị)
                        if (newerMsg.senderId == msg.senderId) {
                          showAvatar = false;
                        }
                      }

                      // 2. [MỚI] Logic hiện Header Ngày (Giống Zalo)
                      bool showDateHeader = false;

                      // Nếu là tin nhắn cuối cùng của list (tức là tin cũ nhất lịch sử) -> Luôn hiện ngày
                      if (index == messages.length - 1) {
                        showDateHeader = true;
                      } else {
                        // So sánh với tin nhắn cũ hơn (index + 1)
                        final olderMsg = messages[index + 1];
                        if (!_isSameDay(msg.timestamp, olderMsg.timestamp)) {
                          showDateHeader = true;
                        }
                      }

                      // 3. Ghép lại
                      return Column(
                        children: [
                          // Vì reverse: true, nên phần tử đầu tiên của Column sẽ nằm "trên"
                          if (showDateHeader) _buildDateHeader(msg.timestamp),

                          MessageBubble(
                            message: msg,
                            isMe: msg.isMe,
                            showAvatar: showAvatar,
                          ),
                        ],
                      );
                    },
                  ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.blue.shade50,
            child: Icon(
              Icons.waving_hand,
              size: 40,
              color: Colors.blue.shade400,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Start chatting with ${widget.chatName}",
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.image, color: Color(0xFF2260FF), size: 28),
              onPressed: _pickAndSendImage, // Gọi hàm chọn ảnh
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F2F2),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    hintText: "Type a message...",
                    hintStyle: TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    isDense: true,
                  ),
                  minLines: 1,
                  maxLines: 4,
                  onSubmitted: (_) => _handleTextSubmit(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _handleTextSubmit,
              child: CircleAvatar(
                backgroundColor: Colors.blue[600],
                radius: 24,
                child: const Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // String _formatTime(String timestamp) {
  //   if (timestamp.isEmpty) return "";
  //   try {
  //     DateTime dt = DateTime.parse(timestamp).toLocal();
  //     return DateFormat('HH:mm').format(dt);
  //   } catch (e) {
  //     return "";
  //   }
  // }

  void _fetchInitialRoomStatus() async {
    // Nếu là chat nhóm hoặc không có partnerId thì bỏ qua
    if (widget.partnerId == null) return;

    try {
      // Gọi API getRoomDetails mà bạn vừa sửa ở Backend
      final data = await _chatApi.getRoomDetails(widget.roomId);
      print("📦 DATA API TRẢ VỀ: $data");

      // Data trả về cấu trúc: { ..., "members": [ { "id": 1, "isOnline": true }, ... ] }
      List<dynamic> members = data['members'];

      // Tìm người mình đang chat (Partner)
      var partner = members.firstWhere((m) {
        // Ép kiểu về String hết để so sánh cho chuẩn
        return m['id'].toString() == widget.partnerId.toString();
      }, orElse: () => null);
      if (partner != null) {
        bool onlineStatus = partner['online'] ?? partner['isOnline'] ?? false;
        // Cập nhật UI
        if (mounted) {
          setState(() {
            isPartnerOnline = onlineStatus;
          });
          print(
            "✅ Đã cập nhật trạng thái Partner: ${onlineStatus ? 'Online' : 'Offline'}",
          );
        }
      }
    } catch (e) {
      print("⚠️ Không lấy được trạng thái Online: $e");
    }
  }

  // 1. Kiểm tra 2 ngày có trùng nhau không
  bool _isSameDay(String? time1, String? time2) {
    if (time1 == null || time2 == null) return false;
    DateTime d1 = DateTime.parse(time1).toLocal();
    DateTime d2 = DateTime.parse(time2).toLocal();
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  // 2. Widget hiển thị Header ngày (Cái cục màu xám ở giữa)
  Widget _buildDateHeader(String timestamp) {
    DateTime date = DateTime.parse(timestamp).toLocal();
    DateTime now = DateTime.now();
    String text = "";

    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      text = "Hôm nay";
    } else if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day - 1) {
      text = "Hôm qua";
    } else {
      text = DateFormat('dd/MM/yyyy').format(date);
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey[300], // Màu nền xám giống Zalo
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
