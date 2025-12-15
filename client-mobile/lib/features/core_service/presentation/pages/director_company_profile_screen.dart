import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:dio/dio.dart'; // 🔴 1. Import Dio để upload file
import '../../../../core/config/app_colors.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/utils/custom_snackbar.dart';
import '../../../../core/widgets/custom_text_field.dart';

class DirectorCompanyProfileScreen extends StatefulWidget {
  const DirectorCompanyProfileScreen({super.key});

  @override
  State<DirectorCompanyProfileScreen> createState() =>
      _DirectorCompanyProfileScreenState();
}

class _DirectorCompanyProfileScreenState
    extends State<DirectorCompanyProfileScreen> {
  final _nameController = TextEditingController();
  final _industryController = TextEditingController();
  final _descController = TextEditingController();
  final _domainController = TextEditingController();

  String? _serverLogoUrl;
  File? _localImageFile;

  bool _isLoading = true;
  bool _isSaving = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _fetchCompanyInfo();
  }

  Future<void> _fetchCompanyInfo() async {
    try {
      final client = ApiClient();
      final response = await client.get('/company/me');

      if (mounted) {
        final data = response.data;
        _nameController.text = data['name'] ?? '';
        _domainController.text = data['domain'] ?? '';
        _industryController.text = data['industry'] ?? '';
        _descController.text = data['description'] ?? '';

        setState(() {
          _serverLogoUrl = data['logoUrl'];
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        setState(() {
          _localImageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      CustomSnackBar.show(
        context,
        title: "Error",
        message: "Cannot pick image: $e",
        isError: true,
      );
    }
  }

  // 🔴 2. HÀM UPLOAD ẢNH SANG STORAGE SERVICE (PORT 8090)
  Future<String?> _uploadImage(File imageFile) async {
    try {
      final dio = Dio();
      String fileName = imageFile.path.split('/').last;

      // Tạo form data chứa file
      FormData formData = FormData.fromMap({
        "file": await MultipartFile.fromFile(
          imageFile.path,
          filename: fileName,
        ),
      });

      // Gọi API sang Storage Service (Port 8090)
      var response = await dio.post(
        "http://10.0.2.2:8090/api/files/upload",
        data: formData,
      );

      if (response.statusCode == 200) {
        // Trả về URL ảnh (VD: http://10.0.2.2:8090/img/abc.png)
        return response.data['url'];
      }
    } catch (e) {
      print("Upload error: $e");
      if (mounted) {
        CustomSnackBar.show(
          context,
          title: "Upload Error",
          message: "Could not upload image to storage service",
          isError: true,
        );
      }
    }
    return null;
  }

  // 🔴 3. CẬP NHẬT LOGIC LƯU
  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    try {
      String? finalLogoUrl = _serverLogoUrl;

      // BƯỚC 1: Nếu có chọn ảnh mới -> Upload lên Storage Service trước
      if (_localImageFile != null) {
        // Hiển thị thông báo đang upload (Optional)
        // CustomSnackBar.show(context, title: "Uploading...", message: "Please wait while we upload your logo.");

        String? uploadedUrl = await _uploadImage(_localImageFile!);

        if (uploadedUrl != null) {
          finalLogoUrl = uploadedUrl; // Có link mới thì dùng link mới
        } else {
          throw Exception("Image upload failed. Please try again.");
        }
      }

      // BƯỚC 2: Gọi API cập nhật thông tin về Core Service (Port 8080)
      final client = ApiClient();
      await client.put(
        '/company/me',
        data: {
          "name": _nameController.text.trim(),
          "industry": _industryController.text.trim(),
          "description": _descController.text.trim(),
          "logoUrl": finalLogoUrl, // Gửi URL ảnh (cũ hoặc mới)
        },
      );

      if (mounted) {
        CustomSnackBar.show(
          context,
          title: "Success",
          message: "Company profile updated successfully!",
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          title: "Update Failed",
          message: e.toString(),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Company Profile",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- LOGO ---
                  Center(
                    child: Stack(
                      children: [
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                            image: _getDecorationImage(),
                          ),
                          child:
                              (_localImageFile == null &&
                                  _serverLogoUrl == null)
                              ? Center(
                                  child: Text(
                                    _nameController.text.isNotEmpty
                                        ? _nameController.text[0]
                                        : "C",
                                    style: const TextStyle(
                                      fontSize: 40,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              : null,
                        ),

                        // Nút Camera
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                PhosphorIconsBold.camera,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  // --- FORM ---
                  _buildSectionTitle("General Information"),
                  const SizedBox(height: 15),

                  _buildLabel("Company Name"),
                  CustomTextField(
                    controller: _nameController,
                    hintText: "E.g. FPT Software",
                  ),

                  _buildLabel("Industry / Sector"),
                  CustomTextField(
                    controller: _industryController,
                    hintText: "E.g. Technology...",
                    prefixIcon: Icon(
                      PhosphorIconsRegular.buildings,
                      color: Colors.grey,
                    ),
                  ),

                  _buildLabel("Domain (Fixed)"),
                  CustomTextField(
                    controller: _domainController,
                    hintText: "domain",
                    readOnly: true,
                    fillColor: Colors.grey[100],
                    prefixIcon: Icon(
                      PhosphorIconsRegular.globe,
                      color: Colors.grey,
                    ),
                  ),

                  const SizedBox(height: 30),

                  // --- DESCRIPTION ---
                  _buildSectionTitle("About Company"),
                  const SizedBox(height: 15),

                  CustomTextField(
                    controller: _descController,
                    hintText: "Describe your company...",
                    maxLines: 5,
                  ),

                  const SizedBox(height: 40),

                  // --- SAVE BUTTON ---
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 5,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              "Save Changes",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  DecorationImage? _getDecorationImage() {
    if (_localImageFile != null) {
      return DecorationImage(
        image: FileImage(_localImageFile!),
        fit: BoxFit.cover,
      );
    }
    if (_serverLogoUrl != null && _serverLogoUrl!.isNotEmpty) {
      return DecorationImage(
        image: NetworkImage(_serverLogoUrl!),
        fit: BoxFit.cover,
      );
    }
    return null;
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 15),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: Color(0xFF64748B),
        ),
      ),
    );
  }
}
