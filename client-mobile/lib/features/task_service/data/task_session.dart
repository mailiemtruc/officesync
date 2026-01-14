// D:\officesync\client-mobile\lib\features\task_service\data\task_session.dart
import 'models/task_user.dart';

class TaskSession {
  // Sử dụng Singleton để truy cập mọi lúc trong module task_service
  static final TaskSession _instance = TaskSession._internal();
  factory TaskSession() => _instance;
  TaskSession._internal();

  int? userId;
  int? companyId;
  int? departmentId; // Thêm trường này để phục vụ bộ lọc mặc định
  String? role;

  // Hàm này sẽ được gọi sau khi user nạp profile thành công
  void setSession(TaskUser user) {
    userId = user.id;
    companyId = user.companyId;
    departmentId = user.departmentId;
    role = user.role;
    // Thêm dòng này để kiểm tra
    print("---------- TASK SESSION SET ----------");
    print("Active ID: $userId - Role: $role");
    print("--------------------------------------");
  }

  // Hàm xóa dữ liệu khi đăng xuất hoặc xóa phiên làm việc
  void clear() {
    userId = null;
    companyId = null;
    departmentId = null;
    role = null;
  }
}
