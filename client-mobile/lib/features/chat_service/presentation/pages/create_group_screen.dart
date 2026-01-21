import 'package:flutter/material.dart';
import '../../data/chat_api.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({Key? key}) : super(key: key);

  @override
  _CreateGroupScreenState createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final ChatApi _chatApi = ChatApi();
  List<ChatUser> users = [];
  List<String> selectedIds = []; // Danh sách ID những người được chọn
  final TextEditingController _nameController = TextEditingController();
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  void _loadUsers() async {
    final list = await _chatApi.fetchAllUsers();
    setState(() {
      users = list;
      isLoading = false;
    });
  }

  void _createGroup() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please enter group name")));
      return;
    }
    if (selectedIds.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Select at least 1 member")));
      return;
    }

    // Gọi API tạo nhóm
    bool success = await _chatApi.createGroup(
      _nameController.text,
      selectedIds,
    );

    if (success) {
      Navigator.pop(
        context,
        true,
      ); // Trả về true để màn hình danh sách reload lại
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Tạo nhóm thất bại")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "New Group",
          style: TextStyle(
            color: Color(0xFF2260FF), // [SỬA] Màu xanh 2260FF
            fontSize: 24,
            fontFamily: 'Inter',
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        // [SỬA] Nút Back màu 2260FF
        iconTheme: const IconThemeData(color: Color(0xFF2260FF)),
      ),
      body: Column(
        children: [
          // 1. Ô nhập tên nhóm
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "Group Name",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.group),
              ),
            ),
          ),
          const Divider(),
          // 2. Danh sách nhân viên để chọn
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      final isSelected = selectedIds.contains(user.id);
                      return CheckboxListTile(
                        title: Text(user.name),
                        subtitle: Text(user.email),
                        value: isSelected,
                        secondary: CircleAvatar(
                          backgroundImage: NetworkImage(user.avatar),
                        ),
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              selectedIds.add(user.id);
                            } else {
                              selectedIds.remove(user.id);
                            }
                          });
                        },
                      );
                    },
                  ),
          ),
          // 3. Nút tạo
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _createGroup,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
                child: Text("Create Group (${selectedIds.length} members)"),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
