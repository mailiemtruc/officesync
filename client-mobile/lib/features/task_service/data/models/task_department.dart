class TaskDepartment {
  final int id;
  final String name;
  final int? companyId;
  final int? managerId;

  TaskDepartment({
    required this.id,
    required this.name,
    this.companyId,
    this.managerId,
  });

  factory TaskDepartment.fromJson(Map<String, dynamic> json) {
    return TaskDepartment(
      id: json['id'] is int ? json['id'] : (json['id'] as num).toInt(),
      name: json['name'] ?? json['departmentName'] ?? '',
      companyId: json['companyId'] is int
          ? json['companyId']
          : (json['companyId'] is num
                ? (json['companyId'] as num).toInt()
                : null),
      managerId: json['managerId'] ?? json['manager_id'],
    );
  }
}
