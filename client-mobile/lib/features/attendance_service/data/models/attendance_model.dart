// features/attendance_service/data/models/attendance_model.dart

class AttendanceModel {
  final int id;
  final String checkInTime;
  final String locationName;
  final String status;
  final String? type;

  AttendanceModel({
    required this.id,
    required this.checkInTime,
    required this.locationName,
    required this.status,
    this.type,
  });

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    return AttendanceModel(
      id: json['id'] ?? 0,
      // [FIX] Nếu null hoặc rỗng, lấy giờ hiện tại để không bị crash khi parse
      checkInTime: (json['checkInTime'] == null || json['checkInTime'] == "")
          ? DateTime.now().toIso8601String()
          : json['checkInTime'],
      locationName: json['locationName'] ?? 'Unknown',
      status: json['status'] ?? 'UNKNOWN',
      type: json['type'],
    );
  }
}
