import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../../data/attendance_api.dart';
import '../../data/models/attendance_model.dart';
import '../../../../core/config/app_colors.dart'; // Nếu bạn có file màu chung, hoặc xóa dòng này dùng Colors cứng
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ManagerAttendanceScreen extends StatefulWidget {
  final String userRole; // Truyền Role (HR_MANAGER hoặc DIRECTOR)

  const ManagerAttendanceScreen({super.key, required this.userRole});

  @override
  State<ManagerAttendanceScreen> createState() =>
      _ManagerAttendanceScreenState();
}

class _ManagerAttendanceScreenState extends State<ManagerAttendanceScreen> {
  final AttendanceApi _api = AttendanceApi();
  final _storage = const FlutterSecureStorage();

  // Biến trạng thái
  DateTime _selectedDate = DateTime.now();
  List<AttendanceModel> _records = [];
  bool _isLoading = false;

  // Màu chủ đạo (Lấy theo app của bạn)
  static const Color primaryColor = Color(0xFF2260FF);

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  // Hàm gọi API lấy dữ liệu toàn công ty
  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      String? userIdStr = await _storage.read(key: 'userId');

      // [LOGIC MỚI] Nếu userId chưa có, thử tìm trong 'user_info' (Backup)
      if (userIdStr == null) {
        print("⚠️ Không tìm thấy key 'userId', đang thử lấy từ 'user_info'...");
        String? userInfoStr = await _storage.read(key: 'user_info');

        if (userInfoStr != null) {
          try {
            final userJson = jsonDecode(userInfoStr);
            if (userJson['id'] != null) {
              userIdStr = userJson['id'].toString();
              // Lưu lại luôn để lần sau không phải tìm nữa
              await _storage.write(key: 'userId', value: userIdStr);
              print("✅ Đã khôi phục UserID: $userIdStr từ user_info");
            }
          } catch (e) {
            print("❌ Lỗi parse user_info: $e");
          }
        }
      }

      // Kiểm tra lần cuối
      if (userIdStr == null) {
        print("⛔ Vẫn không tìm thấy User ID. Vui lòng đăng nhập lại.");
        setState(() => _isLoading = false);
        return;
      }

      int userId = int.parse(userIdStr);
      print("🚀 Đang gọi API với UserID: $userId");

      final data = await _api.getManagerAllAttendance(
        userId,
        widget.userRole,
        _selectedDate.month,
        _selectedDate.year,
      );

      setState(() {
        _records = data;
      });
    } catch (e) {
      print("Error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Hàm thay đổi tháng
  void _changeMonth(int monthsToAdd) {
    setState(() {
      _selectedDate = DateTime(
        _selectedDate.year,
        _selectedDate.month + monthsToAdd,
      );
    });
    _fetchData(); // Load lại dữ liệu khi đổi tháng
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "HR Dashboard",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontFamily: 'Inter',
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),

          // 1. THANH CHỌN THÁNG
          _buildMonthSelector(),

          const Divider(thickness: 1, height: 20),

          // 2. DANH SÁCH BẢNG CÔNG
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: primaryColor),
                  )
                : _records.isEmpty
                ? _buildEmptyState()
                : _buildDataTable(),
          ),
        ],
      ),
    );
  }

  // Widget: Thanh chọn tháng
  Widget _buildMonthSelector() {
    final String displayDate = DateFormat('MMMM yyyy').format(_selectedDate);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new,
              size: 20,
              color: Colors.grey,
            ),
            onPressed: () => _changeMonth(-1),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              displayDate,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: primaryColor,
                fontFamily: 'Inter',
              ),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.arrow_forward_ios,
              size: 20,
              color: Colors.grey,
            ),
            onPressed: () => _changeMonth(1),
          ),
        ],
      ),
    );
  }

  // Widget: Hiển thị khi không có dữ liệu
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_outlined, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 10),
          Text(
            "Không có dữ liệu chấm công",
            style: TextStyle(color: Colors.grey[500], fontSize: 16),
          ),
        ],
      ),
    );
  }

  // Widget: Bảng dữ liệu chính
  Widget _buildDataTable() {
    // Dùng SingleChildScrollView 2 lần để cuộn được cả ngang và dọc
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      physics: const BouncingScrollPhysics(),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: DataTable(
            columnSpacing: 24, // Khoảng cách giữa các cột
            headingRowColor: MaterialStateProperty.all(const Color(0xFFF8F9FD)),
            columns: const [
              DataColumn(
                label: Text(
                  'ID',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Ngày',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Giờ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Loại',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataColumn(
                label: Text(
                  'Vị trí',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
            rows: _records.map((record) {
              final date =
                  DateTime.tryParse(record.checkInTime) ?? DateTime.now();
              final isCheckIn = record.type == "CHECK_IN";

              return DataRow(
                cells: [
                  // ID bản ghi (Hoặc UserID nếu bạn sửa Model)
                  DataCell(
                    Text(
                      "#${record.id}",
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  // Ngày (dd/MM)
                  DataCell(Text(DateFormat('dd/MM').format(date))),
                  // Giờ (HH:mm)
                  DataCell(
                    Text(
                      DateFormat('HH:mm').format(date),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  // Loại (Badge màu)
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isCheckIn
                            ? Colors.green.withOpacity(0.1)
                            : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isCheckIn ? Colors.green : Colors.orange,
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        isCheckIn ? "Vào" : "Ra",
                        style: TextStyle(
                          color: isCheckIn
                              ? Colors.green[700]
                              : Colors.orange[800],
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  // Vị trí
                  DataCell(
                    SizedBox(
                      width: 120, // Giới hạn chiều rộng tên vị trí
                      child: Text(
                        record.locationName,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
