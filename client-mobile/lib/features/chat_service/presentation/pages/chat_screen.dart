import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';

// Import đúng các file trong project
import '../../data/chat_api.dart';
import '../../data/models/chat_room.dart';
import '../../data/models/chat_socket_service.dart'; // [MỚI] Import Socket Service
import 'chat_detail_screen.dart';
import 'create_group_screen.dart';
import 'contact_screen.dart';
import '../../widgets/skeleton_loader.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatApi _chatApi = ChatApi();
  // [MỚI] Khởi tạo Socket Service
  final ChatSocketService _socketService = ChatSocketService();
  final _storage = const FlutterSecureStorage();
  final TextEditingController _searchController = TextEditingController();

  List<ChatRoom> _allRooms = [];
  List<ChatRoom> _filteredRooms = [];
  bool isLoading = true;
  String myId = "";

  @override
  void initState() {
    super.initState();
    _initDataAndSocket();
  }

  @override
  void dispose() {
    // [MỚI] Ngắt kết nối socket khi thoát màn hình này để tránh rò rỉ bộ nhớ
    _socketService.disconnect();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initDataAndSocket() async {
    String? id = await _storage.read(key: 'userId');
    if (id != null) {
      if (mounted) setState(() => myId = id);

      // 1. Load dữ liệu API trước
      await _loadData();

      // 2. Kết nối Socket sau khi đã có dữ liệu nền
      _connectSocket(id);
    }
  }

  void _connectSocket(String userId) {
    _socketService.connect(userId);

    // [QUAN TRỌNG] Lắng nghe sự kiện từ Socket trả về
    _socketService.onMessageReceived = (dynamic data) {
      print("⚡ Socket Event ở ChatScreen: $data");

      // Giả sử data trả về có dạng: { "roomId": 123, "content": "Hello", ... }
      // Tùy vào cấu trúc JSON backend trả về ở kênh /user/queue/notifications

      if (data['roomId'] != null) {
        _handleNewMessage(data);
      } else {
        // Nếu không parse được ID, tốt nhất gọi lại API cho chắc
        _loadData();
      }
    };
  }

  // [LOGIC SỬA LỖI ĐÈ DANH SÁCH]
  void _handleNewMessage(dynamic data) {
    print("⚡ Xử lý tin nhắn Socket: $data");

    if (mounted) {
      setState(() {
        // TRƯỜNG HỢP 1: ĐÂY LÀ SỰ KIỆN TẠO PHÒNG MỚI (Từ code Java vừa sửa)
        if (data['event_type'] == 'NEW_ROOM') {
          print("✨ Có nhóm mới! Thêm ngay vào đầu danh sách.");

          // 1. Parse JSON thành Object ChatRoom
          // (Lưu ý: ChatRoom.fromJson của bạn phải khớp key với Java gửi)
          try {
            ChatRoom newRoom = ChatRoom.fromJson(data);

            // 2. Kiểm tra trùng (cho chắc chắn)
            int index = _allRooms.indexWhere((r) => r.id == newRoom.id);
            if (index == -1) {
              // Chưa có -> Thêm vào đầu
              _allRooms.insert(0, newRoom);
            }
          } catch (e) {
            print("❌ Lỗi parse phòng mới: $e");
            // Nếu lỗi parse thì fallback về cách cũ: Load lại API
            _loadData();
            return;
          }
        }
        // TRƯỜNG HỢP 2: TIN NHẮN THƯỜNG (Cập nhật vị trí phòng cũ)
        else if (data['roomId'] != null) {
          int roomId = data['roomId'] is int
              ? data['roomId']
              : int.tryParse(data['roomId'].toString()) ?? 0;

          // Lấy thời gian từ tin nhắn vừa nhận (hoặc lấy giờ hiện tại luôn cho nhanh)
          String newTime =
              data['timestamp'] ?? DateTime.now().toIso8601String();

          int index = _allRooms.indexWhere((r) => r.id == roomId);
          if (index != -1) {
            ChatRoom existingRoom = _allRooms[index];

            // ✅ [SỬA ĐOẠN NÀY] Tạo room mới với thời gian mới nhất
            ChatRoom updatedRoom = existingRoom.copyWith(updatedAt: newTime);

            _allRooms.removeAt(index);
            _allRooms.insert(0, updatedRoom); // Đẩy room ĐÃ UPDATE lên đầu
          } else {
            _loadData();
          }
        }

        // Cập nhật lại UI tìm kiếm
        if (_searchController.text.isEmpty) {
          _filteredRooms = _allRooms;
        }
      });
    }
  }

  Future<void> _loadData() async {
    try {
      final list = await _chatApi.fetchMyRooms();
      if (mounted) {
        setState(() {
          _allRooms = list;
          // Logic sắp xếp: Phòng mới cập nhật lên đầu (dựa vào updatedAt)
          // Nếu backend chưa sort, ta sort ở đây cho chắc
          _allRooms.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

          _filteredRooms = list;
          isLoading = false;
        });
      }
    } catch (e) {
      print("Lỗi tải danh sách phòng: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _runFilter(String keyword) {
    List<ChatRoom> results = [];
    if (keyword.isEmpty) {
      results = _allRooms;
    } else {
      results = _allRooms
          .where(
            (room) =>
                room.roomName.toLowerCase().contains(keyword.toLowerCase()),
          )
          .toList();
    }
    setState(() {
      _filteredRooms = results;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leadingWidth: 54,
        leading: Padding(
          padding: const EdgeInsets.only(left: 24), // Căn lề 24px giống mẫu
          child: InkWell(
            onTap: () => Navigator.pop(context),
            child: const Align(
              alignment: Alignment.centerLeft,
              child: Icon(
                Icons.arrow_back_ios_new,
                color: Color(0xFF2260FF), // Màu xanh đồng bộ
                size: 24,
              ),
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF2260FF)),

        title: const Text(
          "MESSAGES",
          style: TextStyle(
            color: Color(0xFF2260FF),
            fontSize: 24,
            fontFamily: 'Inter',
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF2260FF).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.people_alt,
                color: Color(0xFF2260FF),
                size: 20,
              ),
            ),
            tooltip: "Contacts",
            onPressed: () async {
              // [SỬA LỖI 1] Thêm await để đợi user thao tác xong ở Contact
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ContactScreen()),
              );
              // Sau khi quay về -> Load lại ngay lập tức
              _loadData();
            },
          ),
          const SizedBox(width: 10),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF2260FF),
        child: const Icon(Icons.edit, color: Colors.white),
        onPressed: () async {
          bool? result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
          );
          // Nếu tạo nhóm thành công (trả về true) -> Load lại
          if (result == true) {
            print("Tạo nhóm thành công, đang reload...");
            _loadData();
          }
        },
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: TextField(
              controller: _searchController,
              onChanged: _runFilter,
              decoration: InputDecoration(
                hintText: "Search chats...",
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: isLoading
                ? const SkeletonListLoader()
                : _filteredRooms.isEmpty
                ? _buildEmptyView()
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: ListView.builder(
                      // Thêm physics này để đảm bảo luôn kéo refresh được kể cả khi list ngắn
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _filteredRooms.length,
                      itemBuilder: (context, index) {
                        final room = _filteredRooms[index];
                        return _buildRoomItem(room);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomItem(ChatRoom room) {
    String displayName = room.roomName;
    bool isGroup = room.type == 'GROUP' || room.type == 'DEPARTMENT';

    String displayAvatar =
        room.avatarUrl ??
        "https://ui-avatars.com/api/?name=${Uri.encodeComponent(displayName)}&background=random&color=fff&size=128";

    return InkWell(
      onTap: () async {
        // [SỬA] Thêm await để khi chat xong quay ra thì cập nhật lại list (ví dụ tin nhắn mới nhất)
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatDetailScreen(
              roomId: room.id,
              chatName: displayName,
              avatarUrl: room.avatarUrl,
            ),
          ),
        );
        // Load lại để cập nhật tin nhắn cuối hoặc thứ tự
        _loadData();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.blue.shade50,
                  backgroundImage: NetworkImage(displayAvatar),
                  child: (room.avatarUrl == null && !isGroup)
                      ? Text(
                          displayName.isNotEmpty
                              ? displayName[0].toUpperCase()
                              : "?",
                          style: TextStyle(
                            color: Colors.blue.shade800,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        )
                      : null,
                ),
                if (isGroup)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: const Icon(
                        Icons.group,
                        size: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _formatDate(room.updatedAt),
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isGroup ? "Group Conversation" : "Private Message",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                      fontStyle: FontStyle.normal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline,
              size: 50,
              color: Colors.blue.shade300,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "No messages yet",
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () async {
              // [SỬA LỖI 1] Logic tương tự nút danh bạ ở trên
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ContactScreen()),
              );
              _loadData();
            },
            style: ElevatedButton.styleFrom(
              shape: const StadiumBorder(),
              elevation: 0,
            ),
            child: const Text("Start a conversation"),
          ),
        ],
      ),
    );
  }

  String _formatDate(String timestamp) {
    if (timestamp.isEmpty) return "";
    try {
      DateTime dt;

      // Trường hợp 1: Backend gửi chuẩn có chữ 'Z' (Vừa sửa ở trên)
      if (timestamp.endsWith('Z')) {
        dt = DateTime.parse(timestamp).toLocal(); // Tự động cộng 7 tiếng
      }
      // Trường hợp 2: API cũ gửi thiếu 'Z'
      else {
        dt = DateTime.parse(
          timestamp + "Z",
        ).toLocal(); // Ép thêm Z rồi cộng 7 tiếng
      }

      DateTime now = DateTime.now();

      // Logic hiển thị: Nếu là hôm nay thì hiện Giờ, khác thì hiện Ngày
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        return DateFormat('HH:mm').format(dt);
      }
      return DateFormat('MMM dd').format(dt);
    } catch (e) {
      return "";
    }
  }
}
