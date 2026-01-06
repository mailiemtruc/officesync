// features/attendance_service/data/models/attendance_model.dart

class AttendanceModel {
  final int id;
  final String checkInTime;
  final String locationName;
  final String status;
  final String? type;
  final String fullName; // [MỚI] Thêm trường này để hiển thị tên nhân viên

  AttendanceModel({
    required this.id,
    required this.checkInTime,
    required this.locationName,
    required this.status,
    this.type,
    required this.fullName, // [MỚI]
  });

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    return AttendanceModel(
      id: json['id'] ?? 0,

      // Giữ nguyên logic cũ: Nếu null thì lấy giờ hiện tại để không crash
      checkInTime: (json['checkInTime'] == null || json['checkInTime'] == "")
          ? DateTime.now().toIso8601String()
          : json['checkInTime'],

      locationName: json['locationName'] ?? 'Unknown',
      status: json['status'] ?? 'UNKNOWN',
      type: json['type'],

      // [MỚI] Map tên từ JSON, nếu null thì hiện Unknown
      fullName: json['fullName'] ?? 'Unknown User',
    );
  }
}
