import 'package:flutter/material.dart';
import '../../data/chat_api.dart';

class ChatInfoScreen extends StatefulWidget {
  final int roomId;
  final bool isGroup;

  const ChatInfoScreen({Key? key, required this.roomId, required this.isGroup})
    : super(key: key);

  @override
  _ChatInfoScreenState createState() => _ChatInfoScreenState();
}

class _ChatInfoScreenState extends State<ChatInfoScreen> {
  final ChatApi _chatApi = ChatApi();
  Map<String, dynamic>? roomInfo;
  bool isLoading = true;

  // Màu xanh chủ đạo của bạn
  final Color primaryColor = const Color(0xFF2260FF);

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  void _loadInfo() async {
    final info = await _chatApi.fetchRoomInfo(widget.roomId);
    if (mounted) {
      setState(() {
        roomInfo = info;
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.isGroup ? "Group Info" : "Chat Info",
          style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: primaryColor),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : roomInfo == null
          ? const Center(child: Text("Load info failed"))
          : SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // 1. Avatar To & Tên
                  _buildHeader(),
                  const SizedBox(height: 30),

                  // 2. Danh sách thành viên (Chỉ hiện nếu là Group)
                  if (widget.isGroup) ...[
                    _buildSectionTitle(
                      "Members (${(roomInfo!['members'] as List).length})",
                    ),
                    _buildMemberList(),
                  ],

                  // 3. Các nút chức năng (Rời nhóm, Block...)
                  const SizedBox(height: 20),
                  _buildActionButtons(),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    String name = roomInfo!['roomName'] ?? "Unknown";
    String? avatar = roomInfo!['avatarUrl'];

    // Fallback avatar logic
    if (avatar == null || avatar.isEmpty) {
      avatar =
          "https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}&size=128";
    }

    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundImage: NetworkImage(avatar),
          backgroundColor: Colors.grey[200],
        ),
        const SizedBox(height: 16),
        Text(
          name,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          widget.isGroup ? "Group Conversation" : "Private Conversation",
          style: TextStyle(color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: TextStyle(
            color: Colors.grey[800],
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildMemberList() {
    List members = roomInfo!['members'] ?? [];
    return ListView.builder(
      shrinkWrap: true, // Quan trọng để nằm trong SingleScrollView
      physics: const NeverScrollableScrollPhysics(),
      itemCount: members.length,
      itemBuilder: (context, index) {
        final m = members[index];
        bool isAdmin = m['role'] == 'ADMIN';

        return ListTile(
          leading: CircleAvatar(
            backgroundImage: NetworkImage(
              m['avatarUrl'] ?? "https://i.pravatar.cc/150",
            ),
          ),
          title: Text(m['fullName']),
          subtitle: Text(m['email']),
          trailing: isAdmin
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    "Admin",
                    style: TextStyle(fontSize: 10, color: Colors.blue),
                  ),
                )
              : null,
        );
      },
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        const Divider(),
        ListTile(
          leading: const Icon(Icons.photo_library, color: Colors.black54),
          title: const Text("View Photos & Files"),
          onTap: () {}, // Tính năng phát triển sau
        ),
        ListTile(
          leading: const Icon(Icons.search, color: Colors.black54),
          title: const Text("Search in Conversation"),
          onTap: () {},
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.red),
          title: Text(
            widget.isGroup ? "Leave Group" : "Delete Chat",
            style: const TextStyle(color: Colors.red),
          ),
          onTap: () {
            // Gọi API rời nhóm ở đây
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Feature coming soon")),
            );
          },
        ),
      ],
    );
  }
}
