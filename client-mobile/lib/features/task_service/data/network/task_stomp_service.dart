import 'dart:convert';
import 'package:stomp_dart_client/stomp.dart';
import 'package:stomp_dart_client/stomp_config.dart';
import 'package:stomp_dart_client/stomp_frame.dart';

import '../task_session.dart';

class TaskStompService {
  StompClient? client;
  final Function(dynamic) onTaskReceived;

  TaskStompService({required this.onTaskReceived});

  void connect() {
    // 1. Đổi IP sang 10.0.2.2 (Dành cho Android Emulator)
    const String serverIp = '10.0.2.2';

    // 2. Cấu hình URL
    // LƯU Ý: Nếu API Gateway (Port 8000) của bạn đã cấu hình forward WebSocket cho Task Service,
    // hãy đổi '8086' thành '8000' để đồng bộ với các service khác (Core, HR).
    // Nếu không, giữ nguyên 8086 để kết nối trực tiếp.

    // Cách 1: Kết nối trực tiếp (như code cũ)
    const String wsUrl = 'ws://$serverIp:8080/ws-task';

    // Cách 2: Kết nối qua Gateway (Khuyên dùng nếu đã cấu hình Gateway)
    // const String wsUrl = 'ws://$serverIp:8000/ws-task';

    client = StompClient(
      config: StompConfig(
        url: wsUrl, // Sử dụng biến wsUrl đã tạo ở trên
        onConnect: (StompFrame frame) {
          _onConnectCallback(frame);
        },
        onWebSocketError: (e) => print("--> [WebSocket Task Error]: $e"),
        onStompError: (frame) => print("--> [Stomp Task Error]: ${frame.body}"),
        onDisconnect: (f) => print("--> [Task Stomp] Disconnected"),
        stompConnectHeaders: {'accept-version': '1.1,1.2'},
        heartbeatIncoming: const Duration(milliseconds: 5000),
        heartbeatOutgoing: const Duration(milliseconds: 5000),
      ),
    );
    client!.activate();
  }

  void _onConnectCallback(StompFrame frame) {
    final userId = TaskSession().userId;
    if (userId != null && client != null) {
      client!.subscribe(
        destination: '/topic/tasks/$userId',
        callback: (StompFrame frame) {
          if (frame.body != null) {
            print("--> [Task Real-time] Nhận dữ liệu cho User $userId");
            onTaskReceived(jsonDecode(frame.body!));
          }
        },
      );
      print("--> [Task Stomp] Đã lắng nghe kênh: /topic/tasks/$userId");
    }
  }

  void disconnect() {
    if (client != null && client!.isActive) {
      client!.deactivate();
    }
  }
}
