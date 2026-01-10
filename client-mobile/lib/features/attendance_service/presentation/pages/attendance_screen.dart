import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';

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

  // --- PALETTE MÀU HIỆN ĐẠI ---
  static const Color primaryColor = Color(0xFF2260FF);
  static const Color bgColor = Color(0xFFF2F2F7);
  static const Color textDark = Color(0xFF1E293B);
  static const Color textGrey = Color(0xFF64748B);

  // Màu trạng thái
  static const Color colorIn = Color(0xFF00B894); // Xanh Teal
  static const Color colorOut = Color(0xFFFA8231); // Cam

  bool _isLoading = false;
  bool _isLoadingHistory = true;

  String? _currentBssid;
  Position? _currentPosition;
  int? _companyId;
  int? _userId;

  String _timeString = "";
  String _dateString = "";
  Timer? _timer;

  // --- DATA & FILTERS ---
  DateTime _selectedMonth = DateTime.now();
  List<AttendanceModel> _allMonthRecords = [];

  DateTime? _filterSpecificDate;
  String _filterType = "ALL";

  @override
  void initState() {
    super.initState();
    _startClock();
    _initData();
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
        _fetchHistoryData();
      }
    } catch (e) {
      debugPrint("Error reading User Info: $e");
    }
  }

  Future<void> _fetchHistoryData() async {
    if (_userId == null) return;

    setState(() => _isLoadingHistory = true);

    try {
      final data = await _api.getHistory(
        _userId!,
        _selectedMonth.month,
        _selectedMonth.year,
      );

      if (mounted) {
        setState(() {
          _allMonthRecords = data;
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _allMonthRecords = [];
          _isLoadingHistory = false;
        });
      }
      debugPrint("Error loading history: $e");
    }
  }

  List<AttendanceModel> _getFilteredRecords() {
    return _allMonthRecords.where((item) {
      if (_filterType != "ALL") {
        if (item.type != _filterType) return false;
      }
      if (_filterSpecificDate != null) {
        DateTime itemDate = DateTime.parse(item.checkInTime);
        bool isSameDay =
            itemDate.year == _filterSpecificDate!.year &&
            itemDate.month == _filterSpecificDate!.month &&
            itemDate.day == _filterSpecificDate!.day;
        if (!isSameDay) return false;
      }
      return true;
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
        _fetchHistoryData();
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          title: "Failed",
          message: e.toString(),
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
      body: SafeArea(
        child: Column(
          children: [
            _buildCustomHeader(),

            Expanded(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
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
                            isLoading:
                                _currentPosition == null &&
                                _currentBssid == null,
                          ),
                          const SizedBox(height: 20),

                          _buildFilterControlSection(filteredList.length),

                          const SizedBox(height: 20),
                          // Header nhỏ cho danh sách
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "HISTORY LOGS",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: textGrey.withOpacity(0.6),
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                  ),

                  // LIST DỮ LIỆU
                  if (_isLoadingHistory)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: Center(
                          child: CircularProgressIndicator(color: primaryColor),
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
                              "No history found",
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
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final item = filteredList[index];
                          final DateTime checkInTime =
                              DateTime.tryParse(item.checkInTime) ??
                              DateTime.now();

                          // Header Ngày
                          bool showHeader = true;
                          if (index > 0) {
                            final DateTime prevTime = DateTime.parse(
                              filteredList[index - 1].checkInTime,
                            );
                            if (DateFormat('dd/MM/yyyy').format(prevTime) ==
                                DateFormat('dd/MM/yyyy').format(checkInTime)) {
                              showHeader = false;
                            }
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (showHeader) _buildDateHeader(checkInTime),
                              // [MỚI] Sử dụng hàm Build Card mới đẹp hơn
                              _buildModernHistoryCard(item, checkInTime),
                            ],
                          );
                        }, childCount: filteredList.length),
                      ),
                    ),

                  const SliverToBoxAdapter(
                    child: SizedBox(height: 100),
                  ), // Bottom padding cho nút
                ],
              ),
            ),
          ],
        ),
      ),
      // Floating Button Check-in
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(
          bottom: 20,
          left: 30,
        ), // Padding left để căn giữa vì FAB mặc định căn phải
        child:
            _buildCheckInButton(), // Đưa nút xuống FAB hoặc giữ ở bottom sheet tùy ý
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  // --- WIDGETS ---

  // Header giống ảnh 2
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
              "ATTENDANCE",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: primaryColor,
                fontFamily: 'Inter',
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildFilterControlSection(int count) {
    final String displayMonth = DateFormat('MMMM yyyy').format(_selectedMonth);

    return Column(
      children: [
        // Hàng 1: Month Selector (Style hiện đại)
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
                  Text(
                    "$count Records",
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

        // Hàng 2: Date & Type Filter
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _pickSpecificDate,
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: _filterSpecificDate != null
                        ? primaryColor
                        : Colors.white,
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
                        color: _filterSpecificDate != null
                            ? Colors.white
                            : textGrey,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _filterSpecificDate != null
                            ? DateFormat('dd/MM').format(_filterSpecificDate!)
                            : "Select Day",
                        style: TextStyle(
                          color: _filterSpecificDate != null
                              ? Colors.white
                              : textDark,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      if (_filterSpecificDate != null) ...[
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () =>
                              setState(() => _filterSpecificDate = null),
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
            ),

            const SizedBox(width: 10),

            // Nút lọc Loại (Chỉ dùng icon để tiết kiệm diện tích)
            _buildTypeFilterIcon(Icons.list, "ALL"),
            const SizedBox(width: 8),
            _buildTypeFilterIcon(Icons.login, "CHECK_IN", color: colorIn),
            const SizedBox(width: 8),
            _buildTypeFilterIcon(Icons.logout, "CHECK_OUT", color: colorOut),
          ],
        ),
      ],
    );
  }

  Widget _buildTypeFilterIcon(IconData icon, String value, {Color? color}) {
    bool isSelected = _filterType == value;
    Color activeColor = color ?? primaryColor; // Default blue for ALL

    return GestureDetector(
      onTap: () => setState(() => _filterType = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? activeColor : Colors.grey.shade200,
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isSelected ? Colors.white : (color ?? textGrey),
        ),
      ),
    );
  }

  Widget _buildClock() {
    return Column(
      children: [
        Text(
          _timeString,
          style: const TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.w900, // Đậm hơn
            color: primaryColor,
            fontFamily: 'Inter',
            height: 1.0, // Chặt dòng
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
    return Container(
      width: MediaQuery.of(context).size.width * 0.85, // Không full màn hình
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleCheckIn,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
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
                children: const [
                  Icon(
                    Icons.fingerprint_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                  SizedBox(width: 12),
                  Text(
                    "CHECK IN NOW",
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

  // --- [UI MỚI] Header ngày tháng đẹp ---
  Widget _buildDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final checkDate = DateTime(date.year, date.month, date.day);

    String label = DateFormat('EEEE, dd MMMM').format(date);
    if (checkDate == today)
      label = "Today";
    else if (checkDate == yesterday)
      label = "Yesterday";

    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: textDark,
              fontWeight: FontWeight.w800,
              fontSize: 13,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // --- [UI MỚI] Card lịch sử "Xịn" ---
  Widget _buildModernHistoryCard(AttendanceModel item, DateTime dateTime) {
    final bool isCheckIn = item.type == "CHECK_IN";
    final Color itemColor = isCheckIn ? colorIn : colorOut;
    final IconData itemIcon = isCheckIn
        ? Icons.login_rounded
        : Icons.logout_rounded;
    final String typeText = isCheckIn ? "CHECK IN" : "CHECK OUT";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        // Để hiệu ứng ripple không tràn ra ngoài
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              // Có thể mở chi tiết sau này
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 1. Icon Container
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: itemColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(itemIcon, color: itemColor, size: 24),
                  ),

                  const SizedBox(width: 16),

                  // 2. Thông tin chính
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Hàng 1: Loại + Badge
                        Row(
                          children: [
                            Text(
                              typeText,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: textDark,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Badge nhỏ status
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: item.status == "LATE"
                                    ? Colors.red.withOpacity(0.1)
                                    : Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item.status == "LATE" ? "LATE" : "OK",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: item.status == "LATE"
                                      ? Colors.red
                                      : Colors.green,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 6),

                        // Hàng 2: Location
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              size: 14,
                              color: textGrey,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                item.locationName,
                                style: const TextStyle(
                                  color: textGrey,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // 3. Thời gian (To & Rõ)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        DateFormat('HH:mm').format(dateTime),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: textDark,
                          fontFamily: 'Inter',
                        ),
                      ),
                      Text(
                        "hrs",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: textGrey.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
