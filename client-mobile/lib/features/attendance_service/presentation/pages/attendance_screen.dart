import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';

import '../../data/attendance_api.dart';
import '../../data/models/attendance_model.dart'; // Dùng cho response check-in
import '../../data/models/timesheet_model.dart'; // [MỚI] Import TimesheetModel
import '../../widgets/wifi_status_card.dart';
import '../../widgets/daily_timesheet_card.dart'; // [MỚI] Import Widget hiển thị thẻ ngày
import '../../../../core/utils/custom_snackbar.dart';
import '../../widgets/skeleton_timesheet_card.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final AttendanceApi _api = AttendanceApi();
  final _storage = const FlutterSecureStorage();

  // --- PALETTE MÀU CŨ (GIỮ NGUYÊN) ---
  static const Color primaryColor = Color(0xFF2260FF);
  static const Color bgColor = Color(0xFFF2F2F7);
  static const Color textDark = Color(0xFF1E293B);
  static const Color textGrey = Color(0xFF64748B);

  bool _isLoading = false;
  bool _isLoadingHistory = true;
  bool _isLocationVerified = false;

  String? _currentBssid;
  Position? _currentPosition;
  int? _companyId;
  int? _userId;

  String _timeString = "";
  String _dateString = "";
  Timer? _timer;

  // --- DATA & FILTERS ---
  DateTime _selectedMonth = DateTime.now();

  // [SỬA] Đổi sang List TimesheetModel
  List<TimesheetModel> _timesheets = [];

  // [MỚI] Biến thống kê
  double _monthlyTotalHours = 0;
  int _monthlyDaysWorked = 0;

  DateTime? _filterSpecificDate;
  // [ĐÃ XÓA] String _filterType vì không còn cần thiết

  @override
  void initState() {
    super.initState();
    _startClock();

    // [TỐI ƯU] Chỉ tải User Info (nhẹ) trước
    _loadUserInfo();

    // [TỐI ƯU] Đợi vẽ xong giao diện mới bắt đầu load GPS/Wifi (Nặng)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeLocationAndWifi();
    });
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
          // Parse an toàn để tránh lỗi kiểu dữ liệu (String/Int) khi cập nhật
          _companyId = int.tryParse(userData['companyId'].toString());
          _userId = int.tryParse(userData['id'].toString());
        });

        // Gọi fetch data
        await _fetchHistoryData();
      } else {
        // [FIX] Nếu không có dữ liệu user -> Phải tắt loading
        debugPrint("User info is null inside AttendanceScreen");
        if (mounted) setState(() => _isLoadingHistory = false);
      }
    } catch (e) {
      debugPrint("Error reading User Info: $e");
      // [FIX] Nếu lỗi khi đọc/parse -> Phải tắt loading
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  // [SỬA] Hàm lấy dữ liệu Timesheet thay vì History
  Future<void> _fetchHistoryData() async {
    // [FIX] Nếu không có userId -> Tắt loading và return
    if (_userId == null) {
      debugPrint("UserId is null, cannot fetch history");
      if (mounted) setState(() => _isLoadingHistory = false);
      return;
    }

    // Đảm bảo bật loading lại nếu đang tắt (phòng hờ)
    // if (mounted) setState(() => _isLoadingHistory = true);

    try {
      final data = await _api.getTimesheet(
        _userId!,
        _selectedMonth.month,
        _selectedMonth.year,
      );

      // Tính toán thống kê
      double totalHours = 0;
      int daysWorked = 0;
      for (var item in data) {
        totalHours += item.totalWorkingHours;
        if (item.sessions.isNotEmpty) daysWorked++;
      }

      final activeDays = data
          .where(
            (day) =>
                day.sessions.isNotEmpty ||
                day.status == 'MISSING_CHECKOUT' ||
                day.totalWorkingHours > 0,
          )
          .toList();

      activeDays.sort((a, b) => b.date.compareTo(a.date));

      if (mounted) {
        setState(() {
          _timesheets = activeDays;
          _monthlyTotalHours = totalHours;
          _monthlyDaysWorked = daysWorked;
          _isLoadingHistory = false; // [QUAN TRỌNG] Tắt loading khi thành công
        });
      }
    } catch (e) {
      debugPrint("Error loading history: $e");
      if (mounted) {
        setState(() {
          _timesheets = [];
          _isLoadingHistory = false; // [QUAN TRỌNG] Tắt loading khi lỗi API
        });
      }
    }
  }

  // [SỬA] Logic lọc chỉ còn lọc theo ngày
  List<TimesheetModel> _getFilteredRecords() {
    if (_filterSpecificDate == null) {
      return _timesheets;
    }
    return _timesheets.where((item) {
      return item.date.year == _filterSpecificDate!.year &&
          item.date.month == _filterSpecificDate!.month &&
          item.date.day == _filterSpecificDate!.day;
    }).toList();
  }

  void _changeMonth(int monthsToAdd) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + monthsToAdd,
      );
      _filterSpecificDate = null;
    });
    _fetchHistoryData();
  }

  Future<void> _pickSpecificDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _filterSpecificDate ?? _selectedMonth,
      firstDate: DateTime(_selectedMonth.year, _selectedMonth.month, 1),
      lastDate: DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0),
      helpText: "FILTER BY DAY",
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: primaryColor,
              onPrimary: Colors.white,
              onSurface: textDark,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: primaryColor),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _filterSpecificDate = picked;
      });
    }
  }

  // Thay thế hàm cũ bằng hàm này
  Future<void> _initializeLocationAndWifi() async {
    // 1. Cho UI thở (Tránh ANR ngay khi vào)
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    // 2. Kiểm tra quyền (nhẹ nhàng)
    var status = await Permission.location.status;
    if (!status.isGranted) {
      status = await Permission.location.request();
    }

    if (status.isGranted) {
      final info = NetworkInfo();

      // --- BƯỚC 1: LẤY DATA CACHE (NHANH) ---
      Position? lastKnown;
      String? bssid;

      try {
        // Chạy song song, timeout cực ngắn để không treo
        final results = await Future.wait([
          Geolocator.getLastKnownPosition(),
          info.getWifiBSSID().timeout(
            const Duration(seconds: 2),
            onTimeout: () => null,
          ),
        ]);

        lastKnown = results[0] as Position?;
        bssid = results[1] as String?;
      } catch (e) {
        debugPrint("Lỗi lấy cache: $e");
      }

      // --- LOGIC "SMART TRUST" (QUAN TRỌNG) ---
      bool isTrusted = false;
      if (lastKnown != null) {
        // Kiểm tra thời gian của vị trí cũ
        final now = DateTime.now();
        final difference = now.difference(lastKnown.timestamp);

        // Nếu vị trí cũ cách đây dưới 10 phút -> Tin cậy luôn -> Cho chấm công ngay!
        if (difference.inMinutes < 4) {
          isTrusted = true;
        }
      }

      if (mounted) {
        setState(() {
          _currentBssid = bssid;
          if (lastKnown != null) _currentPosition = lastKnown;
          // Nếu tin cậy cache thì mở khóa luôn, không cần chờ GPS mới
          _isLocationVerified = isTrusted;
        });
      }

      // Nếu đã tin cậy rồi thì thôi, không cần load nặng nữa (Tránh ANR)
      // Hoặc vẫn load ngầm để cập nhật nhưng không khóa UI
      if (isTrusted) {
        debugPrint(
          "✅ Dùng vị trí Cache (Mới < 4p), bỏ qua High Accuracy để mượt App",
        );
        return;
      }

      // --- BƯỚC 2: NẾU CACHE CŨ QUÁ HOẶC KHÔNG CÓ -> MỚI GỌI GPS CHÍNH XÁC ---
      try {
        // Đợi thêm chút để UI render xong status ở Bước 1
        await Future.delayed(const Duration(milliseconds: 100));

        Position accuratePosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          // Timeout 8s. Nếu quá 8s thì văng ra catch để dùng vị trí cũ
          timeLimit: const Duration(seconds: 8),
        );

        // Lấy lại BSSID mới
        String? newBssid = await info.getWifiBSSID();

        if (mounted) {
          setState(() {
            _currentPosition = accuratePosition;
            _currentBssid = newBssid;
            _isLocationVerified = true; // Mở khóa
          });
        }
      } catch (e) {
        debugPrint("⚠️ Không lấy được GPS mới hoặc Timeout: $e");

        // [QUAN TRỌNG NHẤT - FALLBACK]
        // Nếu load GPS mới thất bại/timeout, NHƯNG ta đã có vị trí cũ (lastKnown)
        // -> Vẫn MỞ KHÓA cho người dùng chấm công bằng vị trí cũ.
        // -> Không bao giờ để người dùng bị kẹt.
        if (mounted && _currentPosition != null) {
          setState(() {
            _isLocationVerified = true; // Mở khóa nút bằng vị trí cũ
          });

          // Nhắc nhẹ người dùng
          CustomSnackBar.show(
            context,
            title: "Weak GPS",
            message: "Using approximate location due to weak signal.",
            backgroundColor: Colors.orange,
          );
        }
      }
    } else {
      // Không có quyền
      if (mounted)
        CustomSnackBar.show(
          context,
          title: "Permission",
          message: "Location permission required",
          isError: true,
        );
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
        // --- [LOGIC MỚI] Xử lý thông báo dựa trên Status trả về ---
        String title = "Success";
        String message = "Attendance was recorded at: ${result.locationName}";
        Color? bgColor; // Mặc định là xanh (Success)

        // 1. Nếu đi muộn (LATE)
        if (result.status == "LATE") {
          title = "Late";
          int minutes = result.lateMinutes ?? 0;
          message = "You were late by $minutes minutes.";
          bgColor = Colors.orange; // Màu cam cảnh báo
        }
        // 2. Nếu là Check-out
        else if (result.type == "CHECK_OUT") {
          title = "Checked out";
          message = "Check-out successful. See you later!";
        }

        CustomSnackBar.show(
          context,
          title: title,
          message: message,
          backgroundColor:
              bgColor, // Truyền màu vào (nếu custom snackbar hỗ trợ)
        );

        _fetchHistoryData(); // Load lại lịch sử để hiện thẻ mới
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          title: "Failed",
          message: e.toString().replaceAll("Exception:", "").trim(),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _getFilteredRecords();

    return Scaffold(
      backgroundColor: bgColor,
      // [THAY ĐỔI 1] Dùng Stack thay vì để body bình thường
      body: Stack(
        children: [
          // --- LỚP 1: NỘI DUNG (GIỮ NGUYÊN CODE CỦA BẠN) ---
          Positioned.fill(
            child: SafeArea(
              bottom: false, // Để nội dung tràn xuống dưới nút một chút cho đẹp
              child: Column(
                children: [
                  _buildCustomHeader(),

                  Expanded(
                    child: CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24.0,
                            ),
                            child: Column(
                              children: [
                                const SizedBox(height: 10),
                                _buildClock(),
                                const SizedBox(height: 20),
                                WifiStatusCard(
                                  bssid: _currentBssid,
                                  lat: _currentPosition?.latitude,
                                  lng: _currentPosition?.longitude,
                                  isLoading:
                                      _currentPosition == null &&
                                      _currentBssid == null,
                                ),
                                const SizedBox(height: 20),
                                _buildFilterControlSection(),
                                const SizedBox(height: 20),

                                // Header nhỏ cho danh sách
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "TIMESHEET LOGS",
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: textGrey.withOpacity(0.6),
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                      if (!_isLoadingHistory &&
                                          _filterSpecificDate == null)
                                        Text(
                                          // Sửa thành toStringAsFixed(2)
                                          "Total: ${_monthlyTotalHours.toStringAsFixed(2)} hrs",
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: primaryColor,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                              ],
                            ),
                          ),
                        ),

                        // LIST DỮ LIỆU
                        if (_isLoadingHistory)
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  return const SkeletonTimesheetCard();
                                },
                                childCount:
                                    5, // Hiển thị giả lập 5 item đang load
                              ),
                            ),
                          )
                        else if (filteredList.isEmpty)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 40),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.02),
                                          blurRadius: 10,
                                          offset: const Offset(0, 5),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.history_toggle_off,
                                      size: 40,
                                      color: Color(0xFFCBD5E1),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    "No records found",
                                    style: TextStyle(
                                      color: textGrey,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate((
                                context,
                                index,
                              ) {
                                return DailyTimesheetCard(
                                  data: filteredList[index],
                                );
                              }, childCount: filteredList.length),
                            ),
                          ),

                        // [QUAN TRỌNG] Khoảng trống dưới cùng để không bị nút che mất nội dung
                        const SliverToBoxAdapter(child: SizedBox(height: 100)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- LỚP 2: NÚT BẤM (ĐÈ LÊN TRÊN & CĂN GIỮA TUYỆT ĐỐI) ---
          Positioned(
            left: 24, // Cách trái 24
            right: 24, // Cách phải 24 => Tự động căn giữa
            bottom: 30, // Cách đáy 30
            child: SafeArea(
              top: false,
              child: _buildCheckInButton(), // Gọi widget nút của bạn
            ),
          ),
        ],
      ),
      // [QUAN TRỌNG] Đã xóa floatingActionButton để tránh xung đột
    );
  }

  // --- WIDGETS GIỮ NGUYÊN (Chỉ chỉnh sửa nhẹ phần Filter) ---

  Widget _buildCustomHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      color: bgColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios,
              color: primaryColor,
              size: 24,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text(
              "MY ATTENDANCE",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: primaryColor,
                fontFamily: 'Inter',
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildFilterControlSection() {
    final String displayMonth = DateFormat('MMMM yyyy').format(_selectedMonth);

    return Column(
      children: [
        // Hàng 1: Month Selector (Giữ nguyên style)
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
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
                icon: const Icon(Icons.chevron_left, size: 24, color: textGrey),
                onPressed: () => _changeMonth(-1),
              ),
              Column(
                children: [
                  Text(
                    displayMonth.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: primaryColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  // [SỬA] Hiển thị thống kê thay vì đếm số record đơn thuần
                  Text(
                    // Sử dụng toStringAsFixed(2) để lấy 2 số thập phân (ví dụ: 10.26)
                    "$_monthlyDaysWorked Days • ${_monthlyTotalHours.toStringAsFixed(2)} Hours",
                    style: const TextStyle(
                      fontSize: 11,
                      color: textGrey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(
                  Icons.chevron_right,
                  size: 24,
                  color: textGrey,
                ),
                onPressed: () {
                  final now = DateTime.now();
                  if (_selectedMonth.month < now.month ||
                      _selectedMonth.year < now.year) {
                    _changeMonth(1);
                  }
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Hàng 2: Date Picker (Giữ nguyên, nhưng xóa bộ lọc Type bên cạnh)
        // Kéo dài Date Picker ra toàn chiều ngang cho đẹp
        GestureDetector(
          onTap: _pickSpecificDate,
          child: Container(
            height: 44,
            width: double.infinity, // Full width
            decoration: BoxDecoration(
              color: _filterSpecificDate != null ? primaryColor : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _filterSpecificDate != null
                    ? primaryColor
                    : Colors.grey.shade200,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.calendar_month_rounded,
                  size: 18,
                  color: _filterSpecificDate != null ? Colors.white : textGrey,
                ),
                const SizedBox(width: 8),
                Text(
                  _filterSpecificDate != null
                      ? "Filtering: ${DateFormat('dd/MM').format(_filterSpecificDate!)}"
                      : "Filter by Specific Date",
                  style: TextStyle(
                    color: _filterSpecificDate != null
                        ? Colors.white
                        : textDark,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                if (_filterSpecificDate != null) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() => _filterSpecificDate = null),
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // [ĐÃ XÓA] Row bộ lọc Type (List/In/Out)
      ],
    );
  }

  Widget _buildClock() {
    return Column(
      children: [
        Text(
          _timeString,
          style: const TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.w900,
            color: primaryColor,
            fontFamily: 'Inter',
            height: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _dateString.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            color: textGrey,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }

  Widget _buildCheckInButton() {
    // Logic hiển thị Text thông minh hơn
    String buttonText = "CHECK IN/OUT NOW";

    if (_isLoading) {
      buttonText = ""; // Đang quay loading
    } else if (!_isLocationVerified) {
      // Nếu đã có vị trí trên màn hình rồi mà chưa verify xong
      if (_currentPosition != null) {
        buttonText =
            "VERIFYING LOCATION..."; // Text này hợp lý hơn "Updating GPS"
      } else {
        buttonText = "LOCATING..."; // Chưa có gì cả
      }
    }

    bool canCheckIn = !_isLoading && _isLocationVerified;

    return Container(
      width: MediaQuery.of(context).size.width * 0.85,
      height: 60,
      decoration: BoxDecoration(
        color: canCheckIn ? primaryColor : Colors.grey, // Xám nếu chưa sẵn sàng
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          if (canCheckIn)
            BoxShadow(
              color: primaryColor.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: ElevatedButton(
        onPressed: canCheckIn ? _handleCheckIn : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (canCheckIn)
                    const Icon(
                      Icons.fingerprint_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  if (canCheckIn) const SizedBox(width: 12),
                  Text(
                    buttonText,
                    style: const TextStyle(
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
}
