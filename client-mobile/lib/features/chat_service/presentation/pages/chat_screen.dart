import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';

// Import đúng các file trong project
import '../../data/chat_api.dart';
import '../../data/models/chat_room.dart';
import 'chat_detail_screen.dart';
import 'create_group_screen.dart';
import 'contact_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatApi _chatApi = ChatApi();
  final _storage = const FlutterSecureStorage();
  final TextEditingController _searchController = TextEditingController();

  List<ChatRoom> _allRooms = []; // Danh sách gốc
  List<ChatRoom> _filteredRooms = []; // Danh sách hiển thị
  bool isLoading = true;
  String myId = "";

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    String? id = await _storage.read(key: 'userId');
    if (id != null) {
      if (mounted) setState(() => myId = id);

      try {
        final list = await _chatApi.fetchMyRooms();
        if (mounted) {
          setState(() {
            _allRooms = list;
            _filteredRooms = list; // Ban đầu hiện tất cả
            isLoading = false;
          });
        }
      } catch (e) {
        print("Lỗi tải danh sách phòng: $e");
        if (mounted) setState(() => isLoading = false);
      }
    }
  }

  // Hàm lọc tìm kiếm
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
        title: const Text(
          "Messages",
          style: TextStyle(
            color: Color(0xFF2260FF),
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false, // Để tiêu đề lệch trái cho hiện đại
        actions: [
          // Nút Danh Bạ (Chỉ giữ lại nút này ở trên)
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
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ContactScreen()),
              ).then((_) => _loadData());
            },
          ),
          const SizedBox(width: 10),
        ],
      ),
      // Dùng Stack để đè nút FAB lên trên
      floatingActionButton: FloatingActionButton(
        backgroundColor: Color(0xFF2260FF),
        child: const Icon(Icons.edit, color: Colors.white),
        onPressed: () async {
          // Nút tạo nhóm nhanh
          bool? result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
          );
          if (result == true) _loadData();
        },
      ),
      body: Column(
        children: [
          // 1. THANH TÌM KIẾM
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

          // 2. DANH SÁCH CHAT
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredRooms.isEmpty
                ? _buildEmptyView()
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: ListView.builder(
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

    // Logic Avatar: Nếu không có ảnh -> Dùng dịch vụ tạo ảnh theo tên
    String displayAvatar =
        room.avatarUrl ??
        "https://ui-avatars.com/api/?name=${Uri.encodeComponent(displayName)}&background=random&color=fff&size=128";

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatDetailScreen(
              roomId: room.id,
              chatName: displayName,
              avatarUrl: room.avatarUrl,
              // Lưu ý: Room model hiện tại chưa có partnerId nên tạm thời chưa truyền
              // initIsOnline, tính năng online sẽ cập nhật khi vào trong.
            ),
          ),
        ).then((_) => _loadData());
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // 1. Avatar
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
                // Nếu là Group thì hiện icon nhỏ ở góc để phân biệt
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

            // 2. Tên & Tin nhắn cuối
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
                    // [TẠM THỜI] Vẫn hiện loại phòng vì API chưa trả về tin nhắn cuối
                    // Sau này Backend update sẽ sửa thành: room.lastMessage
                    isGroup ? "Group Conversation" : "Private Message",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                      fontStyle:
                          FontStyle.normal, // Không in nghiêng nữa cho sạch
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
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ContactScreen()),
              ).then((_) => _loadData());
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
      DateTime dt = DateTime.parse(timestamp).toLocal();
      DateTime now = DateTime.now();
      // Nếu là hôm nay thì hiện giờ
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        return DateFormat('HH:mm').format(dt);
      }
      // Nếu khác ngày thì hiện ngày tháng
      return DateFormat('MMM dd').format(dt);
    } catch (e) {
      return "";
    }
  }
}
