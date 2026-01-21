// File: lib/core/utils/user_update_event.dart (hoặc đường dẫn tùy bạn)
import 'dart:async';

class UserUpdateEvent {
  // Tạo singleton để dùng chung cho toàn app
  static final UserUpdateEvent _instance = UserUpdateEvent._internal();
  factory UserUpdateEvent() => _instance;
  UserUpdateEvent._internal();

  // Tạo luồng dữ liệu (Stream)
  final StreamController<void> _controller = StreamController.broadcast();

  // Các màn hình sẽ lắng nghe cái này
  Stream<void> get onUserUpdated => _controller.stream;

  // Gọi hàm này để thông báo có sự thay đổi
  void notify() {
    _controller.sink.add(null);
  }

  void dispose() {
    _controller.close();
  }
}
