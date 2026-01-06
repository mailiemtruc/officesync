import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

// [MỚI] Import thư viện để lấy vị trí và wifi
import 'package:geolocator/geolocator.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

// Import cấu hình
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
  // Controllers thông tin chung
  final _nameController = TextEditingController();
  final _industryController = TextEditingController();
  final _descController = TextEditingController();
  final _domainController = TextEditingController();

  // [MỚI] Controllers cấu hình chấm công
  final _latController = TextEditingController();
  final _longController = TextEditingController();
  final _radiusController = TextEditingController(
    text: "100.0",
  ); // Mặc định 100m
  final _wifiSsidController = TextEditingController();
  final _wifiBssidController = TextEditingController();

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

  // --- LẤY THÔNG TIN CÔNG TY ---
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

        // [MỚI] Điền thông tin chấm công nếu đã có trên server
        if (data['latitude'] != null)
          _latController.text = data['latitude'].toString();
        if (data['longitude'] != null)
          _longController.text = data['longitude'].toString();
        if (data['allowedRadius'] != null)
          _radiusController.text = data['allowedRadius'].toString();
        if (data['wifiSsid'] != null)
          _wifiSsidController.text = data['wifiSsid'];
        if (data['wifiBssid'] != null)
          _wifiBssidController.text = data['wifiBssid'];

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

  // --- [MỚI] HÀM LẤY VỊ TRÍ & WIFI HIỆN TẠI ---
  Future<void> _getCurrentLocationAndWifi() async {
    setState(() => _isSaving = true); // Tận dụng biến loading xoay nhẹ
    try {
      // 1. Xin quyền Location (Bắt buộc cho cả GPS và lấy BSSID trên Android 10+)
      Map<Permission, PermissionStatus> statuses = await [
        Permission.location,
        Permission.locationWhenInUse,
      ].request();

      if (statuses[Permission.location]!.isDenied) {
        throw Exception(
          "Please grant location permissions to use this feature.",
        );
      }

      // 2. Lấy GPS
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _latController.text = position.latitude.toString();
      _longController.text = position.longitude.toString();

      // 3. Lấy Wifi
      final info = NetworkInfo();
      String? bssid = await info.getWifiBSSID();
      String? ssid = await info.getWifiName();

      // Lưu ý: Trên iOS Simulator sẽ luôn null, cần máy thật
      _wifiBssidController.text = bssid ?? "";
      _wifiSsidController.text = (ssid ?? "").replaceAll(
        '"',
        '',
      ); // Bỏ dấu ngoặc kép

      if (mounted) {
        CustomSnackBar.show(
          context,
          title: "Success",
          message: "Current coordinates and Wi-Fi network have been obtained!",
        );
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          title: "Lỗi",
          message: e.toString().replaceAll("Exception: ", ""),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // --- CHỌN ẢNH TỪ THƯ VIỆN ---
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

  // --- LƯU THAY ĐỔI ---
  Future<void> _saveChanges() async {
    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    try {
      final client = ApiClient();
      String? finalLogoUrl = _serverLogoUrl;

      // 1. Upload ảnh nếu có
      if (_localImageFile != null) {
        finalLogoUrl = await client.uploadImageToStorage(_localImageFile!.path);
      }

      // 2. Cập nhật thông tin sang Core Service
      await client.put(
        '/company/me',
        data: {
          "name": _nameController.text.trim(),
          "industry": _industryController.text.trim(),
          "description": _descController.text.trim(),
          "logoUrl": finalLogoUrl,

          // [MỚI] Gửi thông tin cấu hình chấm công
          "latitude": _latController.text.trim(),
          "longitude": _longController.text.trim(),
          "allowedRadius": _radiusController.text.trim(),
          "wifiBssid": _wifiBssidController.text.trim(),
          "wifiSsid": _wifiSsidController.text.trim(),
        },
      );

      if (mounted) {
        CustomSnackBar.show(
          context,
          title: "Success",
          message: "Company profile & Attendance settings updated!",
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        String msg = e.toString().replaceAll("Exception: ", "");
        CustomSnackBar.show(
          context,
          title: "Update Failed",
          message: msg,
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
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF2260FF)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "COMPANY PROFILE",
          style: TextStyle(
            color: Color(0xFF2260FF),
            fontWeight: FontWeight.bold,
          ),
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
                  // --- AVATAR SECTION ---
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
                                  (_serverLogoUrl == null ||
                                      _serverLogoUrl!.isEmpty))
                              ? Center(
                                  child: Text(
                                    _nameController.text.isNotEmpty
                                        ? _nameController.text[0].toUpperCase()
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

                  // --- GENERAL INFORMATION ---
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

                  // --- [MỚI] ATTENDANCE SETTINGS ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionTitle("Attendance Settings"),
                      // Nút lấy vị trí nhanh
                      InkWell(
                        onTap: _getCurrentLocationAndWifi,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.orange),
                          ),
                          child: Row(
                            children: const [
                              Icon(
                                PhosphorIconsBold.mapPin,
                                size: 16,
                                color: Colors.orange,
                              ),
                              SizedBox(width: 5),
                              Text(
                                "Use Current Location",
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),

                  // Hàng Latitude / Longitude
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel("Latitude"),
                            CustomTextField(
                              controller: _latController,
                              hintText: "10.123...",
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel("Longitude"),
                            CustomTextField(
                              controller: _longController,
                              hintText: "106.123...",
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  _buildLabel("Allowed Radius (meters)"),
                  CustomTextField(
                    controller: _radiusController,
                    hintText: "e.g. 100.0",
                    keyboardType: TextInputType.number,
                  ),

                  _buildLabel("Wi-Fi SSID (Name)"),
                  CustomTextField(
                    controller: _wifiSsidController,
                    hintText: "e.g. Office_Wifi_5G",
                  ),

                  _buildLabel("Wi-Fi BSSID (MAC Address) - Important"),
                  CustomTextField(
                    controller: _wifiBssidController,
                    hintText: "e.g. 00:11:22:33:44:55",
                    prefixIcon: Icon(
                      PhosphorIconsRegular.wifiHigh,
                      color: Colors.grey,
                    ),
                  ),
                  const Text(
                    "* This is crucial for attendance validation.",
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),

                  const SizedBox(height: 30),

                  // --- ABOUT COMPANY ---
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

  // Hàm helper để hiển thị ảnh
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
