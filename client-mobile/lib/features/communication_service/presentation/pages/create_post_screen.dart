import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/config/app_colors.dart';

class CreatePostScreen extends StatefulWidget {
  final Function(String content, File? image) onPost;
  final String myAvatarUrl;

  const CreatePostScreen({
    super.key,
    required this.onPost,
    this.myAvatarUrl = "",
  });

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _contentCtrl = TextEditingController();
  File? _selectedImage;
  final _picker = ImagePicker();

  // Biến kiểm tra xem nút Post có được active không
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    // Lắng nghe thay đổi text để update nút Post
    _contentCtrl.addListener(_validateForm);
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    super.dispose();
  }

  void _validateForm() {
    final hasContent = _contentCtrl.text.trim().isNotEmpty;
    final hasImage = _selectedImage != null;

    // Chỉ cần có Chữ HOẶC có Ảnh là được post
    final isValid = hasContent || hasImage;

    if (_isValid != isValid) {
      setState(() {
        _isValid = isValid;
      });
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
      _validateForm(); // Update lại trạng thái nút Post ngay
    }
  }

  @override
  Widget build(BuildContext context) {
    // Logic Smart Text: Nếu nội dung ngắn (<80 ký tự) thì chữ to, ngược lại chữ nhỏ
    final bool isShortText = _contentCtrl.text.length < 80;

    return Scaffold(
      backgroundColor: Colors.white,
      // Resize để tránh bàn phím che mất toolbar
      resizeToAvoidBottomInset: true,

      // --- 1. APP BAR ---
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leadingWidth: 80,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            "Cancel",
            style: TextStyle(color: Colors.black54, fontSize: 16),
          ),
        ),
        centerTitle: true,
        title: const Text(
          "Create Post",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        actions: [
          // Yêu cầu số 4: Button State Awareness
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: TextButton(
              onPressed: _isValid
                  ? () {
                      widget.onPost(_contentCtrl.text, _selectedImage);
                      Navigator.pop(context);
                    }
                  : null, // Nếu không valid thì disable
              style: TextButton.styleFrom(
                backgroundColor: _isValid
                    ? AppColors.primary
                    : const Color(0xFFF1F5F9),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 0,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                "Post",
                style: TextStyle(
                  color: _isValid ? Colors.white : Colors.grey, // Đổi màu chữ
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),

      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- 2. USER INFO + PRIVACY CHIP ---
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: const Color(0xFFF1F5F9),
                        backgroundImage: widget.myAvatarUrl.isNotEmpty
                            ? NetworkImage(widget.myAvatarUrl)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Me",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Yêu cầu số 5: Privacy Chip
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9), // Nền xám nhạt
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(
                                  Icons.public,
                                  size: 12,
                                  color: Colors.grey,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  "Public",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_drop_down,
                                  size: 14,
                                  color: Colors.grey,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // --- 3. INPUT TEXT (SMART TEXT) ---
                  TextField(
                    controller: _contentCtrl,
                    maxLines: null, // Tự động xuống dòng
                    autofocus: true, // Tự bật bàn phím khi vào
                    decoration: const InputDecoration(
                      hintText: "What's on your mind?",
                      border: InputBorder.none,
                      hintStyle: TextStyle(
                        fontSize: 24,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    // Yêu cầu số 1: Font chữ to/nhỏ tùy độ dài
                    style: TextStyle(
                      fontSize: isShortText ? 24 : 16,
                      color: const Color(0xFF334155),
                      height: 1.4,
                    ),
                    onChanged: (_) => setState(() {}), // Rebuild để đổi cỡ chữ
                  ),

                  // --- 4. IMAGE PREVIEW (DYNAMIC VISIBILITY) ---
                  // Yêu cầu số 2: Chỉ hiện khi có ảnh
                  if (_selectedImage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.file(
                              _selectedImage!,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              // Giới hạn chiều cao max để không chiếm hết màn hình
                              height: 300,
                            ),
                          ),
                          // Nút xóa ảnh (X)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: () {
                                setState(() => _selectedImage = null);
                                _validateForm();
                              },
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Khoảng trống đệm để cuộn không bị kịch
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),

          // --- 5. BOTTOM TOOLBAR (KEYBOARD ACCESSORY) ---
          // Yêu cầu số 3: Thanh công cụ nằm ngang, ưu tiên ảnh
          Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 12,
              bottom:
                  12 +
                  MediaQuery.of(context).padding.bottom, // Safe area cho iOS
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  offset: const Offset(0, -2),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Row(
              children: [
                const Text(
                  "Add to your post",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
                const Spacer(),

                // Nút Ảnh (Primary - Nổi bật nhất)
                IconButton(
                  onPressed: _pickImage,
                  icon: const Icon(
                    PhosphorIconsFill.image,
                    color: AppColors.primary,
                    size: 28,
                  ),
                  tooltip: "Add Photo",
                ),

                // Các nút khác (Disabled/Grey - vì bạn bảo chỉ cho đăng ảnh)
                IconButton(
                  onPressed: null, // Disable
                  icon: const Icon(
                    PhosphorIconsFill.userPlus,
                    color: Color(0xFFCBD5E1),
                    size: 28,
                  ),
                ),
                IconButton(
                  onPressed: null, // Disable
                  icon: const Icon(
                    PhosphorIconsFill.smiley,
                    color: Color(0xFFCBD5E1),
                    size: 28,
                  ),
                ),
                IconButton(
                  onPressed: null, // Disable
                  icon: const Icon(
                    PhosphorIconsFill.mapPin,
                    color: Color(0xFFCBD5E1),
                    size: 28,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
