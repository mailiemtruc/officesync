import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

// Import thư viện để lấy vị trí và wifi
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
  // --- CONTROLLERS ---
  final _nameController = TextEditingController();
  final _industryController = TextEditingController();
  final _descController = TextEditingController();
  final _domainController = TextEditingController();

  final _latController = TextEditingController();
  final _longController = TextEditingController();
  final _radiusController = TextEditingController(text: "100.0");
  final _wifiSsidController = TextEditingController();
  final _wifiBssidController = TextEditingController();
  final _startTimeController = TextEditingController();
  final _endTimeController = TextEditingController();

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

  // Dispose controllers để tránh memory leak
  @override
  void dispose() {
    _nameController.dispose();
    _industryController.dispose();
    _descController.dispose();
    _domainController.dispose();
    _latController.dispose();
    _longController.dispose();
    _radiusController.dispose();
    _wifiSsidController.dispose();
    _wifiBssidController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    super.dispose();
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

        if (data['latitude'] != null) {
          _latController.text = data['latitude'].toString();
        }
        if (data['longitude'] != null) {
          _longController.text = data['longitude'].toString();
        }
        if (data['allowedRadius'] != null) {
          _radiusController.text = data['allowedRadius'].toString();
        }
        _startTimeController.text =
            data['workStartTime'] ?? ''; // Ví dụ: "08:00"
        _endTimeController.text = data['workEndTime'] ?? ''; // Ví dụ: "17:30"

        _wifiSsidController.text = data['wifiSsid'] ?? '';
        _wifiBssidController.text = data['wifiBssid'] ?? '';

        setState(() {
          _serverLogoUrl = data['logoUrl'];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching company info: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        CustomSnackBar.show(
          context,
          title: "Error",
          message: "Unable to load company information",
          isError: true,
        );
      }
    }
  }

  // --- LẤY VỊ TRÍ & WIFI AN TOÀN ---
  Future<void> _getCurrentLocationAndWifi() async {
    FocusScope.of(context).unfocus(); // Ẩn bàn phím
    setState(() => _isSaving = true);

    try {
      // 1. Kiểm tra dịch vụ Location
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception(
          "Please turn on GPS (Location Services) on your device.",
        );
      }

      // 2. Xin quyền Location
      var status = await Permission.location.status;
      if (!status.isGranted) {
        status = await Permission.location.request();
        if (!status.isGranted) {
          throw Exception(
            "Need location permission to get coordinates and Wifi info.",
          );
        }
      }

      // 3. Lấy tọa độ GPS
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      _latController.text = position.latitude.toString();
      _longController.text = position.longitude.toString();

      // 4. Lấy Wifi Info
      final info = NetworkInfo();
      String? bssid = await info.getWifiBSSID();
      String? ssid = await info.getWifiName();

      if (ssid != null) {
        if (ssid.startsWith('"') && ssid.endsWith('"')) {
          ssid = ssid.substring(1, ssid.length - 1);
        }
      }

      _wifiBssidController.text = bssid ?? "";
      _wifiSsidController.text = ssid ?? "";

      if (mounted) {
        String msg = "Coordinates have been updated!";
        if (bssid == null) {
          msg +=
              "\n⚠️ Unable to get Wi-Fi (Please make sure you are connected to Wi-Fi).";
        } else {
          msg += "\nWifi: $ssid";
        }

        CustomSnackBar.show(
          context,
          title: "Success",
          message: msg,
          isError: bssid == null,
        );
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          title: "Error",
          message: e.toString().replaceAll("Exception: ", ""),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _selectTime(TextEditingController controller) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (picked != null) {
      // Format giờ thành dạng HH:mm (ví dụ 08:30)
      final String formattedTime =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      controller.text = formattedTime;
    }
  }

  // --- CHỌN ẢNH ---
  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1024,
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
        message: "Unable to select image: $e",
        isError: true,
      );
    }
  }

  // --- VALIDATE DATA ---
  bool _validateInputs() {
    if (_nameController.text.trim().isEmpty) {
      CustomSnackBar.show(
        context,
        title: "Missing Information",
        message: "Company name cannot be empty",
        isError: true,
      );
      return false;
    }

    try {
      if (_latController.text.isNotEmpty) {
        double lat = double.parse(_latController.text.trim());
        if (lat < -90 || lat > 90)
          throw Exception("Latitude is invalid (-90 to 90)");
      }
      if (_longController.text.isNotEmpty) {
        double long = double.parse(_longController.text.trim());
        if (long < -180 || long > 180)
          throw Exception("Longitude is invalid (-180 to 180)");
      }
      if (_radiusController.text.isNotEmpty) {
        double rad = double.parse(_radiusController.text.trim());
        if (rad <= 0) throw Exception("Radius must be greater than 0");
      }
    } catch (e) {
      CustomSnackBar.show(
        context,
        title: "Invalid Data",
        message: e.toString().replaceAll("Exception: ", ""),
        isError: true,
      );
      return false;
    }

    return true;
  }

  // --- LƯU THAY ĐỔI ---
  Future<void> _saveChanges() async {
    FocusScope.of(context).unfocus();

    if (!_validateInputs()) return;

    setState(() => _isSaving = true);

    try {
      final client = ApiClient();
      String? finalLogoUrl = _serverLogoUrl;

      if (_localImageFile != null) {
        finalLogoUrl = await client.uploadImageToStorage(_localImageFile!.path);
      }

      final lat = double.tryParse(_latController.text.trim());
      final long = double.tryParse(_longController.text.trim());
      final radius = double.tryParse(_radiusController.text.trim());

      await client.put(
        '/company/me',
        data: {
          "name": _nameController.text.trim(),
          "industry": _industryController.text.trim(),
          "description": _descController.text.trim(),
          "logoUrl": finalLogoUrl,
          "latitude": lat,
          "longitude": long,
          "allowedRadius": radius,
          "workStartTime": _startTimeController.text.trim(),
          "workEndTime": _endTimeController.text.trim(),
          "wifiBssid": _wifiBssidController.text.trim(),
          "wifiSsid": _wifiSsidController.text.trim(),
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
          title: "Error",
          message: e.toString().replaceAll("Exception: ", ""),
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
            fontSize: 24, // 👈 Đã thêm cỡ chữ tại đây
            fontFamily: 'Inter',
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
                  _buildAvatarSection(),
                  const SizedBox(height: 30),

                  _buildSectionTitle("General information"),
                  const SizedBox(height: 15),
                  _buildLabel("Company name"),
                  CustomTextField(
                    controller: _nameController,
                    hintText: "Enter company name",
                  ),

                  _buildLabel("Field"),
                  CustomTextField(
                    controller: _industryController,
                    hintText: "For example: Information technology...",
                    prefixIcon: Icon(
                      PhosphorIconsRegular.buildings,
                      color: Colors.grey,
                    ),
                  ),

                  _buildLabel("Domain (Fixed)"),
                  CustomTextField(
                    controller: _domainController,
                    hintText: "domain.com", // Đã thêm hintText
                    readOnly: true,
                    fillColor: Colors.grey[100],
                    prefixIcon: Icon(
                      PhosphorIconsRegular.globe,
                      color: Colors.grey,
                    ),
                  ),

                  const SizedBox(height: 30),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionTitle("Attendance configuration"),
                      InkWell(
                        onTap: _isSaving ? null : _getCurrentLocationAndWifi,
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
                                "Location",
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
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
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
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  _buildLabel("Allowable radius (meters)"),
                  CustomTextField(
                    controller: _radiusController,
                    hintText: "For example: 100.0",
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),

                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel("Start time"),
                            GestureDetector(
                              onTap: () => _selectTime(_startTimeController),
                              child: AbsorbPointer(
                                // Ngăn bàn phím hiện lên
                                child: CustomTextField(
                                  controller: _startTimeController,
                                  hintText: "08:00",
                                  prefixIcon: const Icon(
                                    PhosphorIconsRegular.clock,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel("End time"),
                            GestureDetector(
                              onTap: () => _selectTime(_endTimeController),
                              child: AbsorbPointer(
                                // Ngăn bàn phím hiện lên
                                child: CustomTextField(
                                  controller: _endTimeController,
                                  hintText: "17:30",
                                  prefixIcon: const Icon(
                                    PhosphorIconsRegular.clockAfternoon,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  _buildLabel("Wifi Name (SSID)"),
                  CustomTextField(
                    controller: _wifiSsidController,
                    hintText: "Office_Wifi",
                  ),

                  _buildLabel("Wi-Fi MAC Address (BSSID) - Important"),
                  CustomTextField(
                    controller: _wifiBssidController,
                    hintText: "00:11:22:33:44:55",
                    prefixIcon: Icon(
                      PhosphorIconsRegular.wifiHigh,
                      color: Colors.grey,
                    ),
                  ),
                  const Text(
                    "* Used to authenticate wifi more accurately than the Wifi name.",
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),

                  const SizedBox(height: 30),
                  _buildSectionTitle("Introduction"),
                  const SizedBox(height: 15),
                  CustomTextField(
                    controller: _descController,
                    hintText: "Describe your company...",
                    maxLines: 5,
                  ),

                  const SizedBox(height: 40),
                  _buildSaveButton(),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _buildAvatarSection() {
    return Center(
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
                    (_serverLogoUrl == null || _serverLogoUrl!.isEmpty))
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
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
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
                "Save changes",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
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
