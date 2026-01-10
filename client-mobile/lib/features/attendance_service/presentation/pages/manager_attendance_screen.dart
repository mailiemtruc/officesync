import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/attendance_api.dart';
import '../../data/models/attendance_model.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ManagerAttendanceScreen extends StatefulWidget {
  final String userRole;

  const ManagerAttendanceScreen({super.key, required this.userRole});

  @override
  State<ManagerAttendanceScreen> createState() =>
      _ManagerAttendanceScreenState();
}

class _ManagerAttendanceScreenState extends State<ManagerAttendanceScreen> {
  final AttendanceApi _api = AttendanceApi();

  // --- PALETTE MÀU HIỆN ĐẠI ---
  static const Color primaryColor = Color(0xFF2260FF);
  static const Color bgColor = Color(0xFFF2F2F7);
  static const Color textDark = Color(0xFF1E293B);
  static const Color textGrey = Color(0xFF64748B);

  static const Color colorIn = Color(0xFF00B894); // Xanh Teal
  static const Color colorOut = Color(0xFFFA8231); // Cam

  // --- STATE ---
  DateTime _selectedMonth = DateTime.now();
  List<AttendanceModel> _records = [];
  bool _isLoading = false;
  final _storage = const FlutterSecureStorage();

  // --- FILTERS ---
  String _filterType = "ALL";
  DateTime? _filterSpecificDate;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      String? userIdStr = await _storage.read(key: 'userId');
      if (userIdStr == null) {
        String? userInfoStr = await _storage.read(key: 'user_info');
        if (userInfoStr != null) {
          try {
            final userJson = jsonDecode(userInfoStr);
            userIdStr = userJson['id']?.toString();
            if (userIdStr != null) {
              await _storage.write(key: 'userId', value: userIdStr);
            }
          } catch (e) {
            print("Parse user_info error: $e");
          }
        }
      }

      if (userIdStr == null) {
        setState(() => _isLoading = false);
        return;
      }

      int userId = int.parse(userIdStr);
      final data = await _api.getManagerAllAttendance(
        userId,
        widget.userRole,
        _selectedMonth.month,
        _selectedMonth.year,
      );

      setState(() => _records = data);
    } catch (e) {
      print("Error loading manager data: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<AttendanceModel> _getFilteredRecords() {
    return _records.where((item) {
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

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: "SELECT MONTH",
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
        _selectedMonth = picked;
        _filterSpecificDate = null;
      });
      _fetchData();
    }
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

  @override
  Widget build(BuildContext context) {
    final filteredList = _getFilteredRecords();

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildCustomAppBar(),

            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: primaryColor),
                    )
                  : Column(
                      children: [
                        // Phần Toolbar (Filter)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Column(
                            children: [
                              _buildFilterControlSection(filteredList.length),
                              const SizedBox(height: 16),
                              _buildTypeFilter(),
                            ],
                          ),
                        ),

                        // Danh sách nhân viên
                        Expanded(
                          child: filteredList.isEmpty
                              ? _buildEmptyState()
                              : ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    20,
                                  ),
                                  itemCount: filteredList.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (context, index) =>
                                      _buildModernEmployeeCard(
                                        filteredList[index],
                                      ),
                                ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildCustomAppBar() {
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
              "MANAGER ATTENDANCE",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Row 1: Month Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: _pickMonth,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.calendar_view_month_rounded,
                        color: primaryColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Month View",
                          style: TextStyle(
                            fontSize: 11,
                            color: textGrey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              displayMonth,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: textDark,
                              ),
                            ),
                            const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: textGrey,
                              size: 20,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Record Count Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "$count Records",
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: textGrey,
                  ),
                ),
              ),
            ],
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: Color(0xFFF1F5F9)),
          ),

          // Row 2: Date Filter
          GestureDetector(
            onTap: _pickSpecificDate,
            child: Row(
              children: [
                Icon(
                  Icons.filter_alt_rounded,
                  size: 18,
                  color: _filterSpecificDate != null ? primaryColor : textGrey,
                ),
                const SizedBox(width: 8),
                Text(
                  "Filter Date: ",
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                if (_filterSpecificDate != null)
                  Chip(
                    label: Text(
                      DateFormat('dd/MM/yyyy').format(_filterSpecificDate!),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    backgroundColor: primaryColor,
                    deleteIcon: const Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.white,
                    ),
                    onDeleted: () => setState(() => _filterSpecificDate = null),
                    visualDensity: VisualDensity.compact,
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  )
                else
                  const Text(
                    "All Days",
                    style: TextStyle(
                      fontSize: 13,
                      color: textDark,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                if (_filterSpecificDate == null)
                  const Icon(Icons.chevron_right_rounded, color: textGrey),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip("All", "ALL"),
          const SizedBox(width: 10),
          _buildFilterChip(
            "Check In",
            "CHECK_IN",
            icon: Icons.login_rounded,
            activeColor: colorIn,
          ),
          const SizedBox(width: 10),
          _buildFilterChip(
            "Check Out",
            "CHECK_OUT",
            icon: Icons.logout_rounded,
            activeColor: colorOut,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    String value, {
    IconData? icon,
    Color? activeColor,
  }) {
    bool isSelected = _filterType == value;
    Color color = activeColor ?? primaryColor;

    return GestureDetector(
      onTap: () => setState(() => _filterType = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? color : Colors.grey.shade200),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: isSelected ? Colors.white : textGrey),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : textGrey,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- THẺ NHÂN VIÊN ĐẸP HƠN ---
  Widget _buildModernEmployeeCard(AttendanceModel item) {
    DateTime checkInTime = DateTime.parse(item.checkInTime);
    String timeStr = DateFormat('HH:mm').format(checkInTime);
    String dateStr = DateFormat('dd/MM/yyyy').format(checkInTime);

    bool isLate = item.status == "LATE";
    // Badge status (Late/OnTime)
    Color statusColor = isLate
        ? const Color(0xFFFF4757)
        : const Color(0xFF2ED573);
    Color statusBg = statusColor.withOpacity(0.1);
    String statusText = isLate ? "Late" : "On Time";

    // Logic IN/OUT
    bool isCheckIn = item.type == "CHECK_IN";
    Color typeColor = isCheckIn ? colorIn : colorOut;
    String typeLabel = isCheckIn ? "IN" : "OUT";
    IconData typeIcon = isCheckIn ? Icons.login_rounded : Icons.logout_rounded;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),

          // Avatar
          leading: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Text(
              _getInitials(item.fullName),
              style: const TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ),

          title: Text(
            item.fullName,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: textDark,
            ),
          ),

          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                _buildMiniBadge(
                  item.role,
                  Colors.blue.shade50,
                  Colors.blue.shade700,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    item.departmentName,
                    style: const TextStyle(fontSize: 12, color: textGrey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Phần bên phải (Giờ & Loại)
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Badge IN/OUT
              Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(typeIcon, size: 10, color: typeColor),
                    const SizedBox(width: 4),
                    Text(
                      typeLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: typeColor,
                      ),
                    ),
                  ],
                ),
              ),
              // Time
              Text(
                timeStr,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: textDark,
                ),
              ),
            ],
          ),

          children: [
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 16),

            // Hàng Status & Date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isLate
                            ? Icons.warning_amber_rounded
                            : Icons.check_circle_outline_rounded,
                        size: 14,
                        color: statusColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        statusText.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            _buildDetailRow(Icons.email_outlined, item.email),
            _buildDetailRow(Icons.phone_outlined, item.phone),
            _buildDetailRow(Icons.location_on_outlined, item.locationName),
            _buildDetailRow(Icons.wifi, "BSSID: ${item.deviceBssid ?? 'N/A'}"),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniBadge(String text, Color bg, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: textGrey),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value ?? "N/A",
              style: const TextStyle(
                fontSize: 13,
                color: textDark,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(
              Icons.filter_list_off_rounded,
              size: 48,
              color: Colors.grey[300],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "No records found",
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return "U";
    List<String> parts = name.trim().split(" ");
    if (parts.length > 1) {
      return "${parts[0][0]}${parts[parts.length - 1][0]}".toUpperCase();
    }
    return name[0].toUpperCase();
  }
}
