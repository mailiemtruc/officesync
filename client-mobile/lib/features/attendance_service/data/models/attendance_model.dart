// features/attendance_service/data/models/attendance_model.dart

class AttendanceModel {
  final int id;
  final String checkInTime;
  final String locationName;
  final String status; // ON_TIME, LATE...
  final String? type; // CHECK_IN, CHECK_OUT

  // [THÊM MỚI] Số phút đi muộn (nếu có)
  final int? lateMinutes;

  // --- THÔNG TIN NHÂN VIÊN ---
  final String fullName;
  final String email;
  final String phone;
  final String role;
  final String departmentName;
  final String? dateOfBirth;
  final String? deviceBssid;

  AttendanceModel({
    required this.id,
    required this.checkInTime,
    required this.locationName,
    required this.status,
    this.type,
    this.lateMinutes, // [THÊM VÀO CONSTRUCTOR]

    this.fullName = "Unknown User",
    this.email = "",
    this.phone = "",
    this.role = "STAFF",
    this.departmentName = "General",
    this.dateOfBirth,
    this.deviceBssid,
  });

  /// features/attendance_service/data/models/attendance_model.dart

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    return AttendanceModel(
      id: json['id'] ?? 0,

      // [QUAN TRỌNG] Thay đoạn checkInTime cũ bằng hàm _parseDateTime
      checkInTime: _parseDateTime(json['checkInTime']),

      locationName: json['locationName'] ?? 'Unknown Location',
      status: json['status'] ?? 'UNKNOWN',
      type: json['type'],
      lateMinutes: json['lateMinutes'],
      fullName: json['fullName'] ?? "Unknown User",
      email: json['email'] ?? "No Email",
      phone: json['phone'] ?? "No Phone",
      role: json['role'] ?? "STAFF",
      departmentName: json['departmentName'] ?? "No Dept",
      dateOfBirth: json['dateOfBirth'],
      deviceBssid: json['deviceBssid'],
    );
  }

  // --- HÀM PHỤ TRỢ (Thêm vào cuối class AttendanceModel) ---
  static String _parseDateTime(dynamic input) {
    if (input == null) return DateTime.now().toIso8601String();

    // Trường hợp 1: Backend trả về String chuẩn ("2024-01-21T10:30:00")
    if (input is String) {
      return input.isEmpty ? DateTime.now().toIso8601String() : input;
    }

    // Trường hợp 2: Backend trả về Mảng số ([2024, 1, 21, 10, 30, 0]) -> Đây là lỗi hay gặp nhất!
    if (input is List) {
      if (input.isEmpty) return DateTime.now().toIso8601String();
      try {
        // Lưu ý: List trả về [Năm, Tháng, Ngày, Giờ, Phút, Giây]
        int y = input[0];
        int M = input.length > 1 ? input[1] : 1;
        int d = input.length > 2 ? input[2] : 1;
        int h = input.length > 3 ? input[3] : 0;
        int m = input.length > 4 ? input[4] : 0;
        int s = input.length > 5 ? input[5] : 0;
        // Format lại thành chuỗi ISO để App hiểu
        return DateTime(y, M, d, h, m, s).toIso8601String();
      } catch (e) {
        print("Lỗi parse ngày dạng mảng: $e");
      }
    }
    return DateTime.now().toIso8601String();
  }
}
