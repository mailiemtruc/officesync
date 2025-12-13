class Employee {
  final String id;
  final String name;
  final String role;
  final String department;
  final String imageUrl;
  bool isLocked; // Trạng thái thay đổi được

  Employee({
    required this.id,
    required this.name,
    required this.role,
    required this.department,
    required this.imageUrl,
    this.isLocked = false,
  });
}
