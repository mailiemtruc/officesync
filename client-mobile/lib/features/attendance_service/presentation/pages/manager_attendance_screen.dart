import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

// --- IMPORTS TỪ SOURCE CỦA BẠN ---
import '../../data/attendance_api.dart';
import '../../data/models/attendance_model.dart';
import '../../data/models/timesheet_model.dart';
import '../widgets/daily_timesheet_card.dart';
// [MỚI] Import WebSocket Service
import '../../../../core/services/websocket_service.dart';
import '../../../../core/utils/custom_snackbar.dart';

class ManagerAttendanceScreen extends StatefulWidget {
  final String userRole;

  const ManagerAttendanceScreen({super.key, required this.userRole});

  @override
  State<ManagerAttendanceScreen> createState() =>
      _ManagerAttendanceScreenState();
}

class _ManagerAttendanceScreenState extends State<ManagerAttendanceScreen> {
  final AttendanceApi _api = AttendanceApi();
  final _storage = const FlutterSecureStorage();

  // --- PALETTE MÀU ---
  static const Color primaryColor = Color(0xFF2260FF);
  static const Color bgColor = Color(0xFFF2F2F7);
  static const Color textDark = Color(0xFF1E293B);
  static const Color textGrey = Color(0xFF64748B);

  // --- STATE ---
  DateTime _selectedMonth = DateTime.now();
  bool _isLoading = false;

  // Dữ liệu gốc từ API (Raw Events)
  List<AttendanceModel> _rawRecords = [];

  // Dữ liệu đã xử lý để hiển thị (Grouped by User & Date)
  List<ManagerTimesheetDisplayItem> _processedList = [];

  // --- FILTERS ---
  DateTime? _filterSpecificDate;

  // [MỚI] Biến quản lý WebSocket
  int? _companyId;
  dynamic _subscription; // Lưu callback hủy đăng ký (nếu thư viện hỗ trợ)

  @override
  void initState() {
    super.initState();
    _fetchData();
    // [MỚI] Kích hoạt lắng nghe Realtime
    _setupRealtimeListener();
  }

  @override
  void dispose() {
    // [MỚI] Hủy lắng nghe khi thoát màn hình (Clean up)
    if (_subscription != null) {
      // Tùy vào cách viết WebSocketService của bạn, nếu có hàm unsubscribe thì gọi ở đây
      // WebSocketService().unsubscribe(...);
      WebSocketService().disconnect();
      super.dispose();
    }
    super.dispose();
  }

  // --- [MỚI] HÀM LẮNG NGHE REAL-TIME ---
  Future<void> _setupRealtimeListener() async {
    // 1. Lấy CompanyID từ Storage
    String? userInfoStr = await _storage.read(key: 'user_info');
    if (userInfoStr != null) {
      final userJson = jsonDecode(userInfoStr);
      _companyId = userJson['companyId'];
      // [THÊM LOG] Kiểm tra xem ID có lấy được không
      print("--> [DEBUG] UserInfo JSON: $userJson");
      print("--> [DEBUG] Company ID tìm được: $_companyId");
    }

    if (_companyId == null) {
      // [THÊM] Thử fallback lấy ID từ userRole hoặc api call khác nếu cần
      print("❌ LỖI: CompanyID bị null, không thể subscribe!");
      return;
    }

    final wsService = WebSocketService();
    // Đảm bảo kết nối
    wsService.connect('ws://10.0.2.2:8083/ws');

    // 2. Subscribe đúng kênh công ty
    // Topic này phải khớp với Backend: /topic/company/{id}/attendance
    String topic = '/topic/company/$_companyId/attendance';

    print("--> [Manager] Đang lắng nghe tại: $topic");

    // Gọi hàm subscribe
    wsService.subscribe(topic, (payload) {
      print("--> [SOCKET] Nhận tin nhắn chấm công mới!");
      try {
        // Parse dữ liệu
        Map<String, dynamic> dataMap;
        if (payload is String) {
          dataMap = jsonDecode(payload);
        } else {
          dataMap = payload;
        }

        // Convert sang Model
        AttendanceModel newRecord = AttendanceModel.fromJson(dataMap);

        // Cập nhật UI
        _handleNewRealtimeRecord(newRecord);
      } catch (e) {
        print("Lỗi xử lý tin nhắn socket: $e");
      }
    });
  }

  // --- [MỚI] HÀM XỬ LÝ KHI CÓ RECORD MỚI ---
  void _handleNewRealtimeRecord(AttendanceModel newRecord) {
    if (!mounted) return;

    // Chỉ cập nhật nếu record mới thuộc tháng đang xem
    DateTime recordDate = DateTime.parse(newRecord.checkInTime);
    if (recordDate.month != _selectedMonth.month ||
        recordDate.year != _selectedMonth.year) {
      return;
    }

    setState(() {
      // 1. Thêm vào danh sách Raw
      // (Thêm vào đầu để khi sort lại nó sẽ được xử lý đúng)
      _rawRecords.add(newRecord);

      // 2. Chạy lại logic xử lý dữ liệu (_processData)
      // Hàm này cực kỳ quan trọng: Nó sẽ tự động ghép record mới này
      // với record cũ (nếu có) để tạo thành cặp Check-in/Check-out hoàn chỉnh.
      _processedList = _processData(_rawRecords);
    });

    // 3. Hiện thông báo nhỏ góc dưới
    CustomSnackBar.show(
      context,
      title: "New Attendance",
      message: "${newRecord.fullName} just checked in (${newRecord.type})",
      backgroundColor: const Color(
        0xFF10B981,
      ), // Green color matching your old code
    );
  }

  Future<void> _fetchData() async {
    // Chỉ setState khi màn hình còn hiển thị
    if (mounted) setState(() => _isLoading = true);

    try {
      // 1. Lấy User ID từ Storage
      String? userIdStr = await _storage.read(key: 'userId');
      if (userIdStr == null) {
        String? userInfoStr = await _storage.read(key: 'user_info');
        if (userInfoStr != null) {
          final userJson = jsonDecode(userInfoStr);
          userIdStr = userJson['id']?.toString();
        }
      }

      if (userIdStr == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      int userId = int.parse(userIdStr);

      // 2. Gọi API lấy toàn bộ log chấm công
      final data = await _api.getManagerAllAttendance(
        userId,
        widget.userRole,
        _selectedMonth.month,
        _selectedMonth.year,
      );

      // 3. Xử lý dữ liệu Raw -> Timesheet Model
      // (Hàm này xử lý logic thuần túy nên không cần await/mounted)
      final processed = _processData(data);

      // [QUAN TRỌNG] Kiểm tra mounted trước khi cập nhật dữ liệu
      if (mounted) {
        setState(() {
          _rawRecords = data;
          _processedList = processed;
        });
      }
    } catch (e) {
      print("Error loading manager data: $e");
    } finally {
      // [SỬA LỖI CRASH TẠI ĐÂY]
      // Nếu màn hình đã bị hủy (dispose), dòng này sẽ bị bỏ qua
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Hàm xử lý logic cốt lõi:
  /// Gom các log rời rạc (AttendanceModel) thành bảng công ngày (TimesheetModel)
  List<ManagerTimesheetDisplayItem> _processData(
    List<AttendanceModel> rawList,
  ) {
    Map<String, List<AttendanceModel>> groupedLogs = {};

    // 1. Gom nhóm
    for (var record in rawList) {
      DateTime date = DateTime.parse(record.checkInTime);
      String dateKey = DateFormat('yyyyMMdd').format(date);
      // Gom theo Email + Ngày để phân biệt các nhân viên khác nhau trong cùng 1 ngày
      String key = "${record.email}_$dateKey";

      if (!groupedLogs.containsKey(key)) {
        groupedLogs[key] = [];
      }
      groupedLogs[key]!.add(record);
    }

    List<ManagerTimesheetDisplayItem> result = [];

    // 2. Xử lý logic
    groupedLogs.forEach((key, logs) {
      // Sort tăng dần để duyệt từ sáng -> tối
      logs.sort((a, b) => a.checkInTime.compareTo(b.checkInTime));
      AttendanceModel userInfo = logs.first;

      List<SessionModel> sessions = [];
      double totalHours = 0.0;
      String status = "OK";

      for (int i = 0; i < logs.length; i++) {
        var current = logs[i];

        if (current.type == "CHECK_IN") {
          int lateMinutes = 0;

          if (current.status == "LATE") {
            status = "LATE";
            lateMinutes = current.lateMinutes ?? 0;
          }

          String inTimeStr = DateFormat(
            'HH:mm:ss',
          ).format(DateTime.parse(current.checkInTime));
          String? outTimeStr;
          double duration = 0.0;

          // Tìm cặp OUT
          if (i + 1 < logs.length && logs[i + 1].type == "CHECK_OUT") {
            var next = logs[i + 1];
            outTimeStr = DateFormat(
              'HH:mm:ss',
            ).format(DateTime.parse(next.checkInTime));

            DateTime inDt = DateTime.parse(current.checkInTime);
            DateTime outDt = DateTime.parse(next.checkInTime);
            duration = outDt.difference(inDt).inMinutes / 60.0;
            i++; // Bỏ qua record OUT tiếp theo vì đã ghép cặp rồi
          } else {
            // Logic xử lý quên checkout
            DateTime recordDate = DateTime.parse(current.checkInTime);
            DateTime now = DateTime.now();
            bool isToday =
                recordDate.year == now.year &&
                recordDate.month == now.month &&
                recordDate.day == now.day;

            if (isToday) {
              status = "WORKING";
            } else {
              status = "MISSING_CHECKOUT";
            }
          }

          sessions.add(
            SessionModel(
              checkIn: inTimeStr,
              checkOut: outTimeStr,
              duration: double.parse(duration.toStringAsFixed(1)),
              lateMinutes: lateMinutes,
            ),
          );
          totalHours += duration;
        }
      }

      TimesheetModel timesheet = TimesheetModel(
        date: DateTime.parse(userInfo.checkInTime),
        totalWorkingHours: double.parse(totalHours.toStringAsFixed(1)),
        status: status,
        sessions: sessions,
      );

      result.add(
        ManagerTimesheetDisplayItem(userInfo: userInfo, timesheet: timesheet),
      );
    });

    // Sort kết quả hiển thị: Ngày mới nhất lên đầu
    result.sort((a, b) => b.timesheet.date.compareTo(a.timesheet.date));
    return result;
  }

  // Lọc danh sách theo ngày cụ thể (nếu user chọn filter)
  List<ManagerTimesheetDisplayItem> _getFilteredList() {
    if (_filterSpecificDate == null) {
      return _processedList;
    }
    return _processedList.where((item) {
      DateTime tDate = item.timesheet.date;
      return tDate.year == _filterSpecificDate!.year &&
          tDate.month == _filterSpecificDate!.month &&
          tDate.day == _filterSpecificDate!.day;
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
            colorScheme: const ColorScheme.light(primary: primaryColor),
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
            colorScheme: const ColorScheme.light(primary: primaryColor),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _filterSpecificDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _getFilteredList();

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
                        // Filter Section
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: _buildFilterControlSection(
                            filteredList.length,
                          ),
                        ),

                        // List of Timesheets
                        Expanded(
                          child: filteredList.isEmpty
                              ? _buildEmptyState()
                              : ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    20,
                                  ),
                                  itemCount: filteredList.length,
                                  itemBuilder: (context, index) {
                                    final item = filteredList[index];
                                    return _buildEmployeeTimesheetWrapper(item);
                                  },
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

  Widget _buildEmployeeTimesheetWrapper(ManagerTimesheetDisplayItem item) {
    return Column(
      children: [
        InkWell(
          onTap: () {
            _showEmployeeDetails(item.userInfo);
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _getInitials(item.userInfo.fullName),
                    style: const TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Tên & Info cơ bản
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.userInfo.fullName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "${item.userInfo.role} • ${item.userInfo.departmentName}",
                        style: const TextStyle(fontSize: 12, color: textGrey),
                      ),
                    ],
                  ),
                ),

                const Icon(Icons.info_outline, color: textGrey, size: 20),
              ],
            ),
          ),
        ),

        DailyTimesheetCard(data: item.timesheet),

        const SizedBox(height: 12),
        const Divider(height: 1, color: Color(0xFFE2E8F0)),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildCustomAppBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      color: bgColor,
      child: Row(
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
              "TIMESHEETS",
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
                        Icons.calendar_month,
                        color: primaryColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "View Month",
                          style: TextStyle(fontSize: 11, color: textGrey),
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
                              Icons.keyboard_arrow_down,
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
                  "$count Items",
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: textGrey,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: Color(0xFFF1F5F9)),
          GestureDetector(
            onTap: _pickSpecificDate,
            child: Row(
              children: [
                Icon(
                  Icons.filter_alt,
                  size: 18,
                  color: _filterSpecificDate != null ? primaryColor : textGrey,
                ),
                const SizedBox(width: 8),
                const Text(
                  "Filter Date:",
                  style: TextStyle(fontSize: 13, color: textGrey),
                ),
                const Spacer(),
                if (_filterSpecificDate != null)
                  Chip(
                    label: Text(
                      DateFormat('dd/MM/yyyy').format(_filterSpecificDate!),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    backgroundColor: primaryColor,
                    deleteIcon: const Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.white,
                    ),
                    onDeleted: () => setState(() => _filterSpecificDate = null),
                    visualDensity: VisualDensity.compact,
                  )
                else
                  const Text(
                    "All Days",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                if (_filterSpecificDate == null)
                  const Icon(Icons.chevron_right, color: textGrey),
              ],
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
          Icon(Icons.folder_open_rounded, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            "No timesheets found",
            style: TextStyle(color: Colors.grey[500]),
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

  void _showEmployeeDetails(AttendanceModel user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  _getInitials(user.fullName),
                  style: const TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 28,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Text(
                user.fullName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textDark,
                ),
                textAlign: TextAlign.center,
              ),
              Text(
                user.role,
                style: const TextStyle(
                  fontSize: 14,
                  color: primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),

              _buildDetailRow(Icons.email_outlined, "Email", user.email),
              _buildDetailRow(
                Icons.phone_outlined,
                "Phone",
                user.phone.isNotEmpty ? user.phone : "N/A",
              ),
              _buildDetailRow(
                Icons.business,
                "Department",
                user.departmentName,
              ),
              _buildDetailRow(
                Icons.cake_outlined,
                "Birthday",
                user.dateOfBirth ?? "N/A",
              ),
              _buildDetailRow(
                Icons.phone_android,
                "Device ID (BSSID)",
                user.deviceBssid ?? "Not registered",
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: bgColor,
                    foregroundColor: textDark,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text("Close"),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: textGrey),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: textDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ManagerTimesheetDisplayItem {
  final AttendanceModel userInfo;
  final TimesheetModel timesheet;

  ManagerTimesheetDisplayItem({
    required this.userInfo,
    required this.timesheet,
  });
}
