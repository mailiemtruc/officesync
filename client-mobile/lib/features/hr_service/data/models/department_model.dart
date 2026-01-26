import 'employee_model.dart';

class DepartmentModel {
  final int? id;
  final String name;
  final String? code;
  final String? color;
  final int memberCount;
  final EmployeeModel? manager;
  final List<String>? memberIds;
  final bool isHr;
  DepartmentModel({
    this.id,
    required this.name,
    this.code,
    this.manager,
    this.color,
    this.memberCount = 0,
    this.memberIds,
    this.isHr = false,
  });

  factory DepartmentModel.fromJson(Map<String, dynamic> json) {
    return DepartmentModel(
      id: json['id'],
      name: json['name'] ?? '',
      code: json['departmentCode'],
      color: json['color'],
      memberCount: json['memberCount'] ?? 0,
      isHr: json['isHr'] ?? false,
      manager: json['manager'] != null
          ? EmployeeModel.fromJson(json['manager'])
          : null,
    );
  }

  // Hàm chuyển đổi sang JSON để gửi lên Backend
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {"name": name, "isHr": isHr};

    // Gửi managerId
    if (manager != null && manager!.id != null) {
      data["managerId"] = int.tryParse(
        manager!.id!,
      ); // Backend nhận managerId (Long)
    }

    if (memberIds != null) {
      data["memberIds"] = memberIds!.map((id) => int.tryParse(id)).toList();
    }

    return data;
  }

  // Helper để hiển thị tên trên UI
  @override
  String toString() => name;
}
