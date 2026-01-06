class AttendanceModel {
  final int id;
  final String checkInTime;
  final String locationName;
  final String status;

  AttendanceModel({
    required this.id,
    required this.checkInTime,
    required this.locationName,
    required this.status,
  });

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    return AttendanceModel(
      id: json['id'] ?? 0,
      checkInTime: json['checkInTime'] ?? '',
      locationName: json['locationName'] ?? 'Unknown',
      status: json['status'] ?? 'UNKNOWN',
    );
  }
}
