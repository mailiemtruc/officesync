class UserModel {
  final int id;
  final String fullName;
  final String email;
  final String role;
  final String status;

  UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.status,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? 0,
      fullName: json['fullName'] ?? 'Unknown',
      email: json['email'] ?? '',
      role: json['role'] ?? 'STAFF',
      status: json['status'] ?? 'ACTIVE',
    );
  }
}
