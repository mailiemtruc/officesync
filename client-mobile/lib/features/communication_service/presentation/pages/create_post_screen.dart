import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/config/app_colors.dart'; // Import màu của dự án

class CreatePostScreen extends StatefulWidget {
  final Function(String content, File? image) onPost;

  const CreatePostScreen({super.key, required this.onPost});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _contentCtrl = TextEditingController();
  File? _selectedImage;
  final _picker = ImagePicker();

  // Hàm chọn ảnh từ thư viện
  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _selectedImage = File(image.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leadingWidth: 80,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            "Cancel",
            style: TextStyle(color: Colors.black, fontSize: 16),
          ),
        ),
        centerTitle: true,
        title: const Text(
          "Create Post",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (_contentCtrl.text.isNotEmpty || _selectedImage != null) {
                widget.onPost(_contentCtrl.text, _selectedImage);
                Navigator.pop(context);
              }
            },
            child: const Text(
              "Post",
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // 1. Info User
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                // Avatar giả định (sau này lấy từ User thật)
                const CircleAvatar(
                  radius: 24,
                  backgroundColor: Color(0xFFE2E8F0),
                  child: Icon(Icons.person, color: Colors.grey),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Company Admin", // Tên user
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: const [
                        Text(
                          "Public",
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.public, size: 12, color: Colors.grey),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. Input Text
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  TextField(
                    controller: _contentCtrl,
                    maxLines: null, // Cho phép xuống dòng thoải mái
                    decoration: const InputDecoration(
                      hintText: "What's On Your Mind?",
                      border: InputBorder.none,
                      hintStyle: TextStyle(fontSize: 20, color: Colors.grey),
                    ),
                    style: const TextStyle(fontSize: 20),
                  ),

                  // 3. Image Preview Area
                  if (_selectedImage != null)
                    Container(
                      margin: const EdgeInsets.only(top: 10),
                      width: double.infinity,
                      height: 250,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(
                          image: FileImage(_selectedImage!),
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedImage = null),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    // Placeholder icon máy ảnh to ở giữa giống design
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        height: 200,
                        width: double.infinity,
                        margin: const EdgeInsets.only(top: 20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F5F9),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: Icon(
                            PhosphorIconsBold.camera,
                            size: 64,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 4. Bottom Options
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Column(
              children: [
                _buildOptionItem(
                  PhosphorIconsRegular.image,
                  "Photo/Video",
                  Colors.blue,
                  _pickImage,
                ),
                const Divider(height: 1, indent: 50),
                _buildOptionItem(
                  PhosphorIconsRegular.tag,
                  "Tag Users",
                  Colors.blue,
                  () {},
                ),
                const Divider(height: 1, indent: 50),
                _buildOptionItem(
                  PhosphorIconsRegular.mapPin,
                  "Check-In",
                  Colors.blue,
                  () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 20), // Safe area bottom
        ],
      ),
    );
  }

  Widget _buildOptionItem(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      onTap: onTap,
      dense: true,
      visualDensity: VisualDensity.compact,
    );
  }
}
