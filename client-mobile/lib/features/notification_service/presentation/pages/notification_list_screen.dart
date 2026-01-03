import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Nếu báo lỗi, chạy lệnh: flutter pub add intl
import 'package:officesync/features/notification_service/notification_service.dart';
import '../../models/notification_model.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationListScreen extends StatefulWidget {
  final int userId;
  const NotificationListScreen({super.key, required this.userId});

  @override
  State<NotificationListScreen> createState() => _NotificationListScreenState();
}

class _NotificationListScreenState extends State<NotificationListScreen> {
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;
  @override
  void initState() {
    super.initState();
    _loadData();

    // 👇 CÀI "ĂNG-TEN" LẮNG NGHE TIN MỚI (Real-time)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("🔔 Có tin mới: ${message.notification?.title}");
      if (message.notification != null) {
        if (mounted) {
          setState(() {
            final newNoti = NotificationModel(
              id: DateTime.now().millisecondsSinceEpoch,
              title: message.notification!.title ?? "Thông báo mới",
              body: message.notification!.body ?? "",
              type: "GENERAL",
              referenceId: 0,
              isRead: false,
              createdAt: DateTime.now().toIso8601String(),
            );
            _notifications.insert(0, newNoti);
          });
        }
      }
    });
  }

  void _loadData() async {
    final data = await NotificationService().fetchNotifications(widget.userId);
    if (mounted) {
      setState(() {
        _notifications = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0, // Bỏ bóng đổ cho phẳng đẹp
        centerTitle: true, // Căn giữa tiêu đề
        // 1. Nút Back màu xanh
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF2260FF)),
          onPressed: () => Navigator.pop(context),
        ),

        // 2. Tiêu đề màu xanh và đậm
        title: const Text(
          "THÔNG BÁO", // Viết hoa nhìn cho "Pro"
          style: TextStyle(
            color: Color(0xFF2260FF), // Mã màu xanh chuẩn của App bạn
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: () async => _loadData(),
              child: ListView.builder(
                itemCount: _notifications.length,
                itemBuilder: (context, index) {
                  final noti = _notifications[index];
                  return _buildItem(noti);
                },
              ),
            ),
    );
  }

  Widget _buildItem(dynamic notiItem) {
    NotificationModel noti = notiItem as NotificationModel;
    bool isRead = noti.isRead;

    String timeStr = "";
    if (noti.createdAt.isNotEmpty) {
      try {
        timeStr = DateFormat(
          'HH:mm dd/MM',
        ).format(DateTime.parse(noti.createdAt));
      } catch (_) {}
    }

    // 👇 BỌC CARD TRONG DISMISSIBLE ĐỂ VUỐT
    return Dismissible(
      key: Key(noti.id.toString()), // Key duy nhất để phân biệt
      direction: DismissDirection.endToStart, // Chỉ cho vuốt từ phải sang trái
      // 1. Tạo nền màu đỏ khi vuốt (Giao diện đẹp ở chỗ này)
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 30),
      ),

      // 2. Xử lý khi vuốt xong (Xóa thật)
      onDismissed: (direction) {
        // A. Gọi API xóa ngầm
        NotificationService().deleteNotification(noti.id);

        // B. Xóa khỏi danh sách hiển thị
        setState(() {
          _notifications.removeWhere((item) => item.id == noti.id);
        });

        // C. Hiện thông báo nhỏ bên dưới
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Đã xóa thông báo"),
            duration: Duration(seconds: 1),
          ),
        );
      },

      // 3. Phần giao diện Card cũ nằm ở đây
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        elevation: 0,
        color: isRead ? Colors.white : Colors.blue.withOpacity(0.05),
        shape: RoundedRectangleBorder(
          side: BorderSide(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ), // Căn chỉnh lại cho đẹp
          leading: CircleAvatar(
            backgroundColor: isRead
                ? Colors.grey.shade100
                : Colors.blue.withOpacity(0.1),
            child: Icon(
              Icons.notifications,
              color: isRead ? Colors.grey : Colors.blue,
            ),
          ),
          title: Text(
            noti.title,
            style: TextStyle(
              fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
              fontSize: 15,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 6),
              Text(
                noti.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey.shade700, height: 1.3),
              ),
              const SizedBox(height: 6),
              Text(
                timeStr,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ),
          onTap: () async {
            if (!isRead) {
              NotificationService().markAsRead(noti.id);
              setState(() {
                final index = _notifications.indexWhere((e) => e.id == noti.id);
                if (index != -1) {
                  _notifications[index] = NotificationModel(
                    id: noti.id,
                    title: noti.title,
                    body: noti.body,
                    type: noti.type,
                    referenceId: noti.referenceId,
                    isRead: true,
                    createdAt: noti.createdAt,
                  );
                }
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.notifications_off_outlined, size: 60, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            "Bạn chưa có thông báo nào",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
