import 'employee_model.dart'; // Import EmployeeModel

class DepartmentModel {
  final int? id; // [Sửa] Cho phép null để dùng được cho trang Tạo mới
  final String name;
  final String? code;
  final String? color; // [MỚI] Hứng màu sắc
  final int memberCount; // [MỚI] Hứng số lượng thành viên
  final EmployeeModel? manager; // [Mới] Thêm trường manager
  final List<String>?
  memberIds; // [MỚI] Thêm danh sách ID thành viên để gửi lên
  final bool isHr; // [MỚI]
  DepartmentModel({
    this.id,
    required this.name,
    this.code,
    this.manager,
    this.color,
    this.memberCount = 0, // Mặc định là 0
    this.memberIds,
    this.isHr = false, // [MỚI] Mặc định false
  });

  factory DepartmentModel.fromJson(Map<String, dynamic> json) {
    return DepartmentModel(
      id: json['id'],
      name: json['name'] ?? '',
      code: json['departmentCode'],
      color: json['color'], // Map trường color
      memberCount:
          json['memberCount'] ?? 0, // Map trường memberCount từ @Formula
      isHr: json['isHr'] ?? false, // [MỚI] Parse JSON
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

    // [MỚI] Gửi danh sách memberIds
    if (memberIds != null) {
      data["memberIds"] = memberIds!.map((id) => int.tryParse(id)).toList();
    }

    return data;
  }

  // Helper để hiển thị tên trên UI
  @override
  String toString() => name;
}
