import 'dart:convert';
import 'package:stomp_dart_client/stomp.dart';
import 'package:stomp_dart_client/stomp_config.dart';
import 'package:stomp_dart_client/stomp_frame.dart';

import '../task_session.dart';

class TaskStompService {
  StompClient? client; // Dùng dấu ? vì phiên bản 1.0.0 có thể khởi tạo sau
  final Function(dynamic) onTaskReceived;

  TaskStompService({required this.onTaskReceived});

  void connect() {
    // Địa chỉ IP máy tính chạy backend của bạn
    const String serverIp = '10.0.2.2';

    client = StompClient(
      config: StompConfig(
        // Cổng 8086 dành riêng cho Task Service
        url: 'ws://$serverIp:8000/ws-task',
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
