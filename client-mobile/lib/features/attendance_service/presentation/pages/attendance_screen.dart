import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

// Import các file trong module
import '../../data/attendance_api.dart';
import '../widgets/wifi_status_card.dart';

// Import Widget dùng chung từ Core (nếu có, ví dụ CustomButton)
import '../../../../core/widgets/custom_button.dart'; // Giả sử bạn có file này
import '../../../../core/utils/custom_snackbar.dart'; // CustomSnackBar bạn đã gửi

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final AttendanceApi _api = AttendanceApi();

  bool _isLoading = false;
  String? _currentBssid;
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _initializeLocationAndWifi();
  }

  /// Hàm khởi tạo: Xin quyền -> Lấy Wifi -> Lấy GPS
  Future<void> _initializeLocationAndWifi() async {
    // 1. Xin quyền Location (Bắt buộc cho cả GPS và lấy info Wifi trên Android)
    var status = await Permission.location.request();

    if (status.isGranted) {
      try {
        // 2. Lấy thông tin Wifi
        final info = NetworkInfo();
        String? bssid = await info.getWifiBSSID();

        // 3. Lấy thông tin GPS
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        if (mounted) {
          setState(() {
            _currentBssid = bssid ?? "Unknown (Bật GPS/Wifi?)";
            _currentPosition = position;
          });
        }
      } catch (e) {
        debugPrint("Lỗi lấy thông tin môi trường: $e");
      }
    } else {
      if (mounted) {
        CustomSnackBar.show(
          context,
          title: "Thiếu quyền",
          message: "Vui lòng cấp quyền vị trí để chấm công",
          isError: true,
        );
      }
    }
  }

  Future<void> _handleCheckIn() async {
    if (_currentPosition == null) {
      await _initializeLocationAndWifi();
      if (_currentPosition == null) return;
    }

    setState(() => _isLoading = true);

    try {
      // Gọi API
      final result = await _api.checkIn(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        _currentBssid ?? "",
      );

      if (mounted) {
        // Thành công -> Hiện thông báo
        CustomSnackBar.show(
          context,
          title: "Thành công",
          message: "Đã chấm công tại: ${result.locationName}",
          isError: false,
        );
      }
    } catch (e) {
      if (mounted) {
        // Thất bại -> Hiện lỗi từ API (VD: Sai Wifi, Xa quá)
        CustomSnackBar.show(
          context,
          title: "Chấm công thất bại",
          message: e.toString().replaceAll("Exception: ", ""),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: const Text(
          "Chấm Công",
          style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Widget hiển thị thông tin
            WifiStatusCard(
              bssid: _currentBssid,
              lat: _currentPosition?.latitude,
              lng: _currentPosition?.longitude,
            ),

            const Spacer(),

            // Nút bấm Check-in
            // Nếu bạn chưa có CustomButton, dùng ElevatedButton thường
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleCheckIn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2260FF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "XÁC NHẬN CHẤM CÔNG",
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
