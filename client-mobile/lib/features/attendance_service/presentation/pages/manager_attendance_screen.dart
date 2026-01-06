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

  // --- PALETTE MÀU ---
  static const Color primaryColor = Color(0xFF2260FF);
  static const Color bgColor = Color(
    0xFFF2F2F7,
  ); // [ĐỔI] Màu nền giống trang Note
  static const Color textDark = Color(0xFF1E293B);
  static const Color textGrey = Color(0xFF64748B);

  DateTime _selectedDate = DateTime.now();
  List<AttendanceModel> _records = [];
  bool _isLoading = false;
  final _storage = const FlutterSecureStorage();

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
        _selectedDate.month,
        _selectedDate.year,
      );

      setState(() => _records = data);
    } catch (e) {
      print("Error loading manager data: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: primaryColor,
              onPrimary: Colors.white,
              onSurface: textDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
      _fetchData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      // [QUAN TRỌNG] Bỏ AppBar mặc định, dùng SafeArea + Custom Header
      body: SafeArea(
        child: Column(
          children: [
            // 1. HEADER GIỐNG TRANG NOTE
            _buildCustomAppBar(),

            // 2. THANH CÔNG CỤ (FILTER)
            _buildFilterToolbar(),

            // 3. DANH SÁCH NHÂN VIÊN
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: primaryColor),
                    )
                  : _records.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      itemCount: _records.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) =>
                          _buildModernEmployeeCard(_records[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS ---

  // [MỚI] Header giống hệt trang Note
  Widget _buildCustomAppBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      color: bgColor, // Màu F2F2F7
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Nút Back
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios,
              color: primaryColor,
              size: 22,
            ),
            onPressed: () => Navigator.pop(context),
          ),

          // Title
          // Dùng Expanded để chữ luôn ở giữa, kể cả khi nút bên phải ẩn
          const Expanded(
            child: Text(
              "MANAGE ATTENDANCE",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize:
                    22, // Giảm nhẹ so với 24 vì chữ này dài hơn chữ "NOTE"
                fontWeight: FontWeight.w800,
                color: primaryColor,
                fontFamily: 'Inter',
              ),
            ),
          ),

          // Widget rỗng bên phải để cân bằng với nút Back bên trái
          // Giúp chữ Tiêu đề nằm chính giữa màn hình
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildFilterToolbar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16), // Bo tròn mềm mại hơn
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
          // Nút chọn tháng
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
                    Icons.calendar_month,
                    color: primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Time",
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          DateFormat('MM/yyyy').format(_selectedDate),
                          style: const TextStyle(
                            color: textDark,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down, color: textGrey),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Badge số lượng
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              "${_records.length} Employees",
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernEmployeeCard(AttendanceModel item) {
    DateTime checkInTime = DateTime.parse(item.checkInTime);
    String timeStr = DateFormat('HH:mm').format(checkInTime);
    String dateStr = DateFormat('dd/MM/yyyy').format(checkInTime);

    bool isLate = item.status == "LATE";
    Color statusColor = isLate
        ? const Color(0xFFFF4757)
        : const Color(0xFF2ED573);
    Color statusBg = statusColor.withOpacity(0.1);
    String statusText = isLate ? "Late" : "On time";

    return Container(
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
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),

          leading: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              _getInitials(item.fullName),
              style: const TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
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
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _buildModernBadge(
                  item.departmentName,
                  Colors.grey.shade100,
                  textGrey,
                ),
                _buildModernBadge(
                  item.role,
                  const Color(0xFFEef2FF),
                  primaryColor,
                ),
              ],
            ),
          ),

          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                timeStr,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: textDark,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),

          children: [
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.cake, "Date of Birth", item.dateOfBirth),
            _buildInfoRow(Icons.phone, "Phone", item.phone),
            _buildInfoRow(Icons.email, "Email", item.email),
            _buildInfoRow(Icons.location_on, "Location", item.locationName),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _buildInfoRow(
                    Icons.wifi,
                    "BSSID",
                    item.deviceBssid,
                    padding: 0,
                  ),
                ),
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernBadge(String text, Color bg, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String? value, {
    double padding = 6,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: padding),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[400]),
          const SizedBox(width: 8),
          Text(
            "$label: ",
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          Expanded(
            child: Text(
              value ?? "N/A",
              style: const TextStyle(
                fontSize: 13,
                color: textDark,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
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
          Icon(Icons.filter_list_off, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            "No data dots",
            style: TextStyle(color: Colors.grey[500], fontSize: 16),
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
