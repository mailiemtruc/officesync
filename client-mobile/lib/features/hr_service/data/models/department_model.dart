import 'employee_model.dart'; // Import EmployeeModel

class DepartmentModel {
  final int? id; // [Sửa] Cho phép null để dùng được cho trang Tạo mới
  final String name;
  final String? code;
  final EmployeeModel? manager; // [Mới] Thêm trường manager

  DepartmentModel({this.id, required this.name, this.code, this.manager});

  factory DepartmentModel.fromJson(Map<String, dynamic> json) {
    return DepartmentModel(
      id: json['id'],
      name: json['name'] ?? '',
      code: json['departmentCode'],
      // Map manager nếu backend trả về
      manager: json['manager'] != null
          ? EmployeeModel.fromJson(json['manager'])
          : null,
    );
  }

  // Hàm chuyển đổi sang JSON để gửi lên Backend
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {"name": name};

    // Nếu có chọn manager, gửi object manager chứa ID để Backend map relation
    if (manager != null && manager!.id != null) {
      data["manager"] = {"id": int.tryParse(manager!.id!)};
    }

    return data;
  }

  // Helper để hiển thị tên trên UI
  @override
  String toString() => name;
}
