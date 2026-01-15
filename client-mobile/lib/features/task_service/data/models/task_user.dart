class TaskUser {
  final int id;
  final String fullName;
  final String email;
  final int? companyId;
  final String? role;
  final String? status;
  final int? departmentId;

  TaskUser({
    required this.id,
    required this.fullName,
    required this.email,
    this.companyId,
    this.role,
    this.status,
    this.departmentId,
  });

  factory TaskUser.fromJson(Map<String, dynamic> json) {
    return TaskUser(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      fullName: json['fullName'] ?? json['full_name'] ?? '',
      email: json['email'] ?? '',
      companyId: json['companyId'] is int
          ? json['companyId']
          : (json['companyId'] is num
                ? (json['companyId'] as num).toInt()
                : null),
      role: json['role'],
      status: json['status'],
      departmentId: (json['departmentId'] ?? json['department_id']) != null
          ? int.parse(
              (json['departmentId'] ?? json['department_id']).toString(),
            )
          : null,
    );
  }
}
