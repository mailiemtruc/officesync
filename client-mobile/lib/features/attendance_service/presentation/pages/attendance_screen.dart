import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';

import '../../data/attendance_api.dart';
import '../../data/models/attendance_model.dart';
import '../widgets/wifi_status_card.dart';
import '../../../../core/utils/custom_snackbar.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final AttendanceApi _api = AttendanceApi();
  final _storage = const FlutterSecureStorage();

  static const Color primaryColor = Color(0xFF2260FF);

  bool _isLoading = false;
  String? _currentBssid;
  Position? _currentPosition;
  int? _companyId;
  int? _userId;

  // Biến đồng hồ
  String _timeString = "";
  String _dateString = "";
  Timer? _timer;

  // [MỚI] Biến quản lý tháng đang xem
  DateTime _selectedDate = DateTime.now();

  // Biến lịch sử
  late Future<List<AttendanceModel>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _startClock();
    _initData();
    _historyFuture = Future.value([]);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startClock() {
    _updateTime();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (Timer t) => _updateTime(),
    );
  }

  void _updateTime() {
    final DateTime now = DateTime.now();
    if (mounted) {
      setState(() {
        _timeString = DateFormat('HH:mm:ss').format(now);
        _dateString = DateFormat('EEEE, dd/MM/yyyy').format(now);
      });
    }
  }

  Future<void> _initData() async {
    await _loadUserInfo();
    await _initializeLocationAndWifi();
  }

  Future<void> _loadUserInfo() async {
    try {
      String? userInfoStr = await _storage.read(key: 'user_info');
      if (userInfoStr != null) {
        final userData = jsonDecode(userInfoStr);
        setState(() {
          _companyId = userData['companyId'];
          _userId = userData['id'];
        });
        _refreshHistory();
      }
    } catch (e) {
      debugPrint("Error reading User Info: $e");
    }
  }

  // [ĐÃ SỬA] Load lịch sử theo Tháng/Năm đang chọn
  void _refreshHistory() {
    if (_userId != null) {
      setState(() {
        _historyFuture = _api.getHistory(
          _userId!,
          _selectedDate.month, // Truyền tháng
          _selectedDate.year, // Truyền năm
        );
      });
    }
  }

  // [MỚI] Hàm thay đổi tháng
  void _changeMonth(int monthsToAdd) {
    setState(() {
      _selectedDate = DateTime(
        _selectedDate.year,
        _selectedDate.month + monthsToAdd,
      );
    });
    _refreshHistory(); // Gọi lại API lấy dữ liệu tháng mới
  }

  Future<void> _initializeLocationAndWifi() async {
    var status = await Permission.location.request();
    if (status.isGranted) {
      try {
        final info = NetworkInfo();
        String? bssid = await info.getWifiBSSID();
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        if (mounted) {
          setState(() {
            _currentBssid = bssid;
            _currentPosition = position;
          });
        }
      } catch (e) {
        debugPrint("Env error: $e");
      }
    }
  }

  Future<void> _handleCheckIn() async {
    if (_companyId == null) return;

    setState(() => _isLoading = true);
    try {
      final result = await _api.checkIn(
        _companyId!,
        _currentPosition?.latitude ?? 0.0,
        _currentPosition?.longitude ?? 0.0,
        _currentBssid ?? "",
      );

      if (mounted) {
        CustomSnackBar.show(
          context,
          title: "Success!",
          message: "Checked in at: ${result.locationName}",
        );
        _refreshHistory(); // Reload lại list sau khi chấm công
      }
    } catch (e) {
      if (mounted)
        CustomSnackBar.show(
          context,
          title: "Failed",
          message: e.toString(),
          isError: true,
        );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: const Text(
          "ATTENDANCE",
          style: TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.w800,
            fontFamily: 'Inter',
            fontSize: 22,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: primaryColor,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const SizedBox(height: 10),
              _buildClock(),
              const SizedBox(height: 20),

              WifiStatusCard(
                bssid: _currentBssid,
                lat: _currentPosition?.latitude,
                lng: _currentPosition?.longitude,
                isLoading: _currentPosition == null && _currentBssid == null,
              ),

              const SizedBox(height: 20),

              // [MỚI] Thanh chọn tháng
              _buildMonthSelector(),

              const SizedBox(height: 15),

              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Recent Activity",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                    fontFamily: 'Inter',
                  ),
                ),
              ),
              const SizedBox(height: 10),

              Expanded(child: _buildHistoryList()),

              const SizedBox(height: 15),

              _buildCheckInButton(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // [MỚI] Widget chọn tháng
  Widget _buildMonthSelector() {
    final String displayDate = DateFormat('MMMM yyyy').format(_selectedDate);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new,
              size: 18,
              color: Colors.grey,
            ),
            onPressed: () => _changeMonth(-1),
          ),
          Text(
            displayDate,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: primaryColor,
              fontFamily: 'Inter',
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.arrow_forward_ios,
              size: 18,
              color: Colors.grey,
            ),
            onPressed: () {
              // Không cho chọn tháng tương lai
              final now = DateTime.now();
              if (_selectedDate.month < now.month ||
                  _selectedDate.year < now.year) {
                _changeMonth(1);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildClock() {
    return Column(
      children: [
        Text(
          _timeString,
          style: const TextStyle(
            fontSize: 42,
            fontWeight: FontWeight.bold,
            color: primaryColor,
            fontFamily: 'Inter',
            letterSpacing: -1,
          ),
        ),
        Text(
          _dateString,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
            fontFamily: 'Inter',
          ),
        ),
      ],
    );
  }

  Widget _buildCheckInButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleCheckIn,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.fingerprint, color: Colors.white, size: 24),
                  SizedBox(width: 10),
                  Text(
                    "CONFIRM ATTENDANCE",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Inter',
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildHistoryList() {
    return FutureBuilder<List<AttendanceModel>>(
      future: _historyFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        } else if (snapshot.hasError) {
          return Center(
            child: Text(
              "Error loading history",
              style: TextStyle(color: Colors.grey[500]),
            ),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 40, color: Colors.grey[300]),
                const SizedBox(height: 8),
                Text(
                  "No history for this month",
                  style: TextStyle(color: Colors.grey[400]),
                ),
              ],
            ),
          );
        }

        final history = snapshot.data!;

        return ListView.builder(
          itemCount: history.length,
          physics: const BouncingScrollPhysics(),
          itemBuilder: (context, index) {
            final item = history[index];
            final DateTime checkInTime =
                DateTime.tryParse(item.checkInTime) ?? DateTime.now();
            final String dateHeader = DateFormat(
              'dd/MM/yyyy',
            ).format(checkInTime);

            bool showHeader = true;
            if (index > 0) {
              final DateTime prevTime = DateTime.parse(
                history[index - 1].checkInTime,
              );
              final String prevDate = DateFormat('dd/MM/yyyy').format(prevTime);
              if (prevDate == dateHeader) showHeader = false;
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showHeader)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      _getDateLabel(checkInTime),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                _buildHistoryItemCard(item, checkInTime),
              ],
            );
          },
        );
      },
    );
  }

  String _getDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final checkDate = DateTime(date.year, date.month, date.day);

    if (checkDate == today) return "Today";
    if (checkDate == yesterday) return "Yesterday";
    return DateFormat('EEE, dd MMM yyyy').format(date);
  }

  Widget _buildHistoryItemCard(AttendanceModel item, DateTime dateTime) {
    final bool isCheckIn = item.type == "CHECK_IN";
    final Color statusColor = isCheckIn
        ? Colors.green
        : (item.type == "CHECK_OUT" ? Colors.orange : primaryColor);
    final IconData statusIcon = isCheckIn
        ? Icons.login
        : (item.type == "CHECK_OUT" ? Icons.logout : Icons.check_circle);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(statusIcon, color: statusColor, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.type?.replaceAll("_", " ") ?? "ATTENDANCE",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 12, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        item.locationName,
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            DateFormat('HH:mm').format(dateTime),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }
}
