class EmployeeModel {
  final String? id;
  final String? employeeCode; // [MỚI] Thêm trường này
  final String fullName;
  final String email;
  final String phone;
  final String dateOfBirth;
  final String role;
  final String status;
  final String? departmentName; // [MỚI] Thêm trường này
  final String? avatarUrl; // [MỚI] Thêm trường này để fix lỗi gạch đỏ

  EmployeeModel({
    this.id,
    this.employeeCode,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.dateOfBirth,
    required this.role,
    this.status = "ACTIVE",
    this.departmentName,
    this.avatarUrl, // [MỚI]
  });

  // 1. Gửi lên Server
  Map<String, dynamic> toJson() {
    return {
      if (id != null) "id": id,
      "employeeCode": employeeCode,
      "fullName": fullName,
      "email": email,
      "phone": phone,
      "dateOfBirth": dateOfBirth,
      "role": role,
      "status": status,
      "avatarUrl": avatarUrl, // [MỚI] Gửi avatarUrl nếu cần
      // Không cần gửi departmentName lên
    };
  }

  // 2. Nhận từ Server
  factory EmployeeModel.fromJson(Map<String, dynamic> json) {
    // Logic lấy tên phòng ban an toàn
    String? deptName;
    if (json['departmentName'] != null) {
      deptName = json['departmentName']; // Lấy từ hàm ảo Java
    } else if (json['department'] != null && json['department'] is Map) {
      deptName = json['department']['name']; // Lấy từ object lồng nhau
    }

    return EmployeeModel(
      id: json['id']?.toString(),
      employeeCode: json['employeeCode']?.toString(), // [MỚI] Map field này
      fullName: json['fullName'] ?? 'Updating...',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      dateOfBirth: json['dateOfBirth']?.toString() ?? '',
      role: json['role'] ?? 'STAFF',
      status: json['status'] ?? 'ACTIVE',
      departmentName: deptName, // [MỚI] Gán tên phòng ban
      avatarUrl: json['avatarUrl'], // [MỚI] Map dữ liệu từ backend
    );
  }
}
