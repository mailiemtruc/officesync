import 'package:flutter/material.dart';
// Import đúng đường dẫn API và ChatDetail của bạn
import '../../data/chat_api.dart';
import 'chat_detail_screen.dart';

class ContactScreen extends StatefulWidget {
  const ContactScreen({Key? key}) : super(key: key);

  @override
  _ContactScreenState createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final ChatApi _chatApi = ChatApi();
  final TextEditingController _searchController = TextEditingController();

  List<ChatUser> _allUsers = []; // Danh sách gốc
  List<ChatUser> _filteredUsers = []; // Danh sách hiển thị (sau khi search)
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Hàm tải dữ liệu
  Future<void> _loadContacts() async {
    final list = await _chatApi.fetchAllUsers();
    if (mounted) {
      setState(() {
        _allUsers = list;
        _filteredUsers = list; // Ban đầu hiển thị hết
        _isLoading = false;
      });
    }
  }

  // Hàm lọc tìm kiếm
  void _runFilter(String keyword) {
    List<ChatUser> results = [];
    if (keyword.isEmpty) {
      results = _allUsers;
    } else {
      results = _allUsers
          .where(
            (user) =>
                user.name.toLowerCase().contains(keyword.toLowerCase()) ||
                user.email.toLowerCase().contains(keyword.toLowerCase()),
          )
          .toList();
    }

    setState(() {
      _filteredUsers = results;
    });
  }

  // Xử lý khi bấm vào user
  void _onContactTap(ChatUser user) async {
    // Hiển thị loading nhẹ
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    // 1. Lấy Room ID từ Backend
    int? roomId = await _chatApi.getPrivateRoomId(user.id);

    // Tắt loading
    Navigator.pop(context);

    if (roomId != null) {
      // 2. Chuyển sang màn hình Chat Detail
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatDetailScreen(
            roomId: roomId,
            chatName: user.name,
            avatarUrl: user.avatar,
            partnerId: user.id,
            initIsOnline: user.isOnline,
          ),
        ),
      ).then((_) {
        // (Tùy chọn) Khi quay lại có thể reload lại trạng thái online
        _loadContacts();
      });
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Cannot create chat room")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Contacts"), // Tiếng Anh
        backgroundColor: Colors.white,
        elevation: 0, // Bỏ bóng cho phẳng, hiện đại
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF2260FF)),
        titleTextStyle: const TextStyle(
          color: Color(0xFF2260FF),
          fontSize: 24,
          fontFamily: 'Inter',
          fontWeight: FontWeight.bold,
        ),
      ),
      body: Column(
        children: [
          // 1. THANH TÌM KIẾM (SEARCH BAR)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => _runFilter(value),
              decoration: InputDecoration(
                hintText: "Search colleagues...", // Tiếng Anh
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[100], // Màu nền xám nhạt hiện đại
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25), // Bo tròn mềm mại
                  borderSide: BorderSide.none, // Bỏ viền đen
                ),
              ),
            ),
          ),

          // 2. DANH SÁCH USER
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadContacts, // Kéo xuống để refresh
                    child: _filteredUsers.isEmpty
                        ? SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: SizedBox(
                              height: MediaQuery.of(context).size.height * 0.6,
                              child: const Center(
                                child: Text(
                                  "No users found", // Tiếng Anh
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _filteredUsers.length,
                            itemBuilder: (context, index) {
                              final user = _filteredUsers[index];
                              return _buildUserTile(user);
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile(ChatUser user) {
    String firstLetter = user.name.isNotEmpty
        ? user.name[0].toUpperCase()
        : "?";
    bool hasImage = user.avatar.isNotEmpty;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      // --- AVATAR + ONLINE STATUS ---
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.blue.shade100,
            backgroundImage: hasImage ? NetworkImage(user.avatar) : null,
            child: !hasImage
                ? Text(
                    firstLetter,
                    style: TextStyle(
                      color: Colors.blue.shade900,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  )
                : null,
          ),
          // Chấm xanh trạng thái (Chỉ hiện khi Online)
          if (user.isOnline)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                ),
              ),
            ),
        ],
      ),
      // --- TÊN & EMAIL ---
      title: Text(
        user.name,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
      subtitle: Text(
        user.email,
        style: TextStyle(color: Colors.grey[600], fontSize: 13),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      // Bỏ icon chat bên phải cho thoáng (Tap vào item là chat rồi)
      onTap: () => _onContactTap(user),
    );
  }
}
