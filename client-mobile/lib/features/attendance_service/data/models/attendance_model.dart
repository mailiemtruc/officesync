// features/attendance_service/data/models/attendance_model.dart

class AttendanceModel {
  final int id;
  final String checkInTime;
  final String locationName;
  final String status; // ON_TIME, LATE...
  final String? type; // CHECK_IN, CHECK_OUT

  // --- THÔNG TIN NHÂN VIÊN MỚI THÊM ---
  final String fullName;
  final String email;
  final String phone;
  final String role;
  final String departmentName;
  final String? dateOfBirth; // Có thể null
  final String? deviceBssid;

  AttendanceModel({
    required this.id,
    required this.checkInTime,
    required this.locationName,
    required this.status,
    this.type,
    // Default values để tránh lỗi null nếu backend chưa trả về kịp
    this.fullName = "Unknown User",
    this.email = "",
    this.phone = "",
    this.role = "STAFF",
    this.departmentName = "General",
    this.dateOfBirth,
    this.deviceBssid,
  });

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    return AttendanceModel(
      id: json['id'] ?? 0,
      checkInTime: (json['checkInTime'] == null || json['checkInTime'] == "")
          ? DateTime.now().toIso8601String()
          : json['checkInTime'],
      locationName: json['locationName'] ?? 'Unknown Location',
      status: json['status'] ?? 'UNKNOWN',
      type: json['type'],

      // Map các trường thông tin nhân viên
      fullName: json['fullName'] ?? "Unknown User",
      email: json['email'] ?? "No Email",
      phone: json['phone'] ?? "No Phone",
      role: json['role'] ?? "STAFF",
      departmentName: json['departmentName'] ?? "No Dept",
      dateOfBirth: json['dateOfBirth'],
      deviceBssid: json['deviceBssid'],
    );
  }
}
