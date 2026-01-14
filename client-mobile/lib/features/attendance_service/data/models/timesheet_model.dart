class TimesheetModel {
  final DateTime date;
  final double totalWorkingHours;
  final String status; // OK, MISSING_CHECKOUT, ABSENT
  final List<SessionModel> sessions;

  TimesheetModel({
    required this.date,
    required this.totalWorkingHours,
    required this.status,
    required this.sessions,
  });

  factory TimesheetModel.fromJson(Map<String, dynamic> json) {
    var list = json['sessions'] as List;
    List<SessionModel> sessionsList = list
        .map((i) => SessionModel.fromJson(i))
        .toList();

    return TimesheetModel(
      date: DateTime.parse(json['date']),
      totalWorkingHours: (json['totalWorkingHours'] as num).toDouble(),
      status: json['status'],
      sessions: sessionsList,
    );
  }
}

class SessionModel {
  final String checkIn;
  final String? checkOut;
  final double duration;
  final int lateMinutes; // [MỚI] Thêm trường này

  SessionModel({
    required this.checkIn,
    this.checkOut,
    required this.duration,
    this.lateMinutes = 0, // [MỚI] Mặc định là 0
  });

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    return SessionModel(
      checkIn: json['checkIn'],
      checkOut: json['checkOut'],
      duration: (json['duration'] as num).toDouble(),
      // [MỚI] Map dữ liệu từ API, nếu không có thì mặc định là 0
      lateMinutes: json['lateMinutes'] ?? 0,
    );
  }
}
