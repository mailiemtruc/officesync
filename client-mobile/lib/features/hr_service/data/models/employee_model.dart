class EmployeeModel {
  // Các trường có thể null nếu server không trả về hoặc chưa có (ví dụ ID khi mới tạo)
  final String? id;
  final String fullName;
  final String email;
  final String phone;
  final String dateOfBirth;
  final String role;
  final String status;

  EmployeeModel({
    this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.dateOfBirth,
    required this.role,
    this.status = "ACTIVE",
  });

  // 1. Dùng để gửi dữ liệu lên Server (Create/Update)
  Map<String, dynamic> toJson() {
    return {
      // Nếu id null thì không gửi (dùng cho Create), có id thì gửi (dùng cho Update)
      if (id != null) "id": id,
      "fullName": fullName,
      "email": email,
      "phone": phone,
      "dateOfBirth": dateOfBirth,
      "role": role,
      "status": status,
    };
  }

  // 2. Dùng để nhận dữ liệu từ Server về (Read) - Chuẩn bị sẵn cho tương lai
  factory EmployeeModel.fromJson(Map<String, dynamic> json) {
    return EmployeeModel(
      id: json['id']?.toString(),
      fullName: json['fullName'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      dateOfBirth: json['dateOfBirth'] ?? '',
      role: json['role'] ?? 'STAFF',
      status: json['status'] ?? 'ACTIVE',
    );
  }
}
