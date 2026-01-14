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

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    return AttendanceModel(
      id: json['id'] ?? 0,
      checkInTime: (json['checkInTime'] == null || json['checkInTime'] == "")
          ? DateTime.now().toIso8601String()
          : json['checkInTime'],
      locationName: json['locationName'] ?? 'Unknown Location',
      status: json['status'] ?? 'UNKNOWN',
      type: json['type'],

      // [THÊM MỚI] Map từ JSON
      lateMinutes: json['lateMinutes'],

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
