import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Nếu báo lỗi, chạy lệnh: flutter pub add intl
import 'package:officesync/features/notification_service/notification_service.dart';
import '../../models/notification_model.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:officesync/features/chat_service/presentation/pages/chat_detail_screen.dart';
import 'package:officesync/features/communication_service/data/newsfeed_api.dart'; // ✅ Import API
import 'package:officesync/features/communication_service/presentation/pages/post_detail_screen.dart'; // ✅ Import màn hình chi tiết

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

  // 👇 [THÊM HÀM NÀY] Xử lý bấm vào thông báo
  void _handleNotificationTap(NotificationModel noti) async {
    // Lấy thông tin từ model
    String type = noti.type;
    int id = noti.referenceId;
    String title = noti.title;

    switch (type) {
      case 'CHAT':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatDetailScreen(
              roomId: id,
              chatName: title, // Lấy tên người gửi làm tên Chat
            ),
          ),
        );
        break;

      case 'ANNOUNCEMENT':
      case 'COMMENT':
      case 'REACTION':
        // Hiển thị loading nhẹ nếu cần
        final post = await NewsfeedApi().getPostById(id);
        if (post != null && mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
          );
        }
        break;

      case 'TASK':
        // Sau này mở cái này
        print("➡️ Đang mở Task ID: $id");
        break;

      case 'LEAVE_REQUEST':
        print("➡️ Đang mở Đơn nghỉ phép ID: $id");
        break;

      default:
        print("⚠️ Loại thông báo chưa hỗ trợ: $type");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        leadingWidth: 54,
        leading: Padding(
          padding: const EdgeInsets.only(left: 24), // Căn lề 24px
          child: InkWell(
            onTap: () => Navigator.pop(context),
            child: const Align(
              alignment: Alignment.centerLeft,
              child: Icon(
                Icons.arrow_back_ios_new, // Icon mũi tên mảnh
                color: Color(0xFF2260FF),
                size: 24,
              ),
            ),
          ),
        ),
        // 2. Tiêu đề màu xanh và đậm
        title: const Text(
          "NOTIFICATION", // Viết hoa nhìn cho "Pro"
          style: TextStyle(
            color: Color(0xFF2260FF), // Mã màu xanh chuẩn của App bạn
            fontWeight: FontWeight.bold,
            fontSize: 24,
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

    // Xử lý thời gian hiển thị gọn gàng
    String timeStr = "";
    if (noti.createdAt.isNotEmpty) {
      try {
        timeStr = DateFormat(
          'HH:mm dd/MM',
        ).format(DateTime.parse(noti.createdAt));
      } catch (_) {}
    }

    return Dismissible(
      key: Key(noti.id.toString()),
      direction: DismissDirection.endToStart,

      // Nền đỏ khi vuốt xóa (có icon thùng rác)
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFF5252),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(
          Icons.delete_sweep_outlined,
          color: Colors.white,
          size: 32,
        ),
      ),

      onDismissed: (direction) {
        NotificationService().deleteNotification(noti.id);
        setState(() {
          _notifications.removeWhere((item) => item.id == noti.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Đã xóa thông báo"),
            duration: Duration(seconds: 1),
          ),
        );
      },

      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16), // Bo góc mềm mại hơn
          // Hiệu ứng đổ bóng (Shadow) tạo chiều sâu
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              spreadRadius: 2,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          // Nếu chưa đọc thì có viền xanh mờ bao quanh
          border: !isRead
              ? Border.all(
                  color: const Color(0xFF2260FF).withOpacity(0.3),
                  width: 1,
                )
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              // Logic khi bấm vào: Đánh dấu đã đọc + Chuyển trang
              if (!isRead) {
                NotificationService().markAsRead(noti.id);
                setState(() {
                  final index = _notifications.indexWhere(
                    (e) => e.id == noti.id,
                  );
                  if (index != -1) {
                    // ✅ Tạo cái mới đè lên cái cũ
                    _notifications[index] = NotificationModel(
                      id: noti.id,
                      title: noti.title,
                      body: noti.body,
                      type: noti.type,
                      referenceId: noti.referenceId,
                      isRead: true, // <--- Chỉ thay đổi đúng chỗ này thành true
                      createdAt: noti.createdAt,
                    );
                  }
                });
              }
              _handleNotificationTap(noti); // Gọi hàm chuyển trang
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- CỘT 1: ICON TRÒN (Thay đổi theo loại thông báo) ---
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _getColorByType(noti.type), // Màu nền nhạt
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getIconByType(noti.type), // Icon tương ứng
                      color: _getIconColorByType(noti.type), // Màu icon đậm
                      size: 22,
                    ),
                  ),

                  const SizedBox(width: 16),

                  // --- CỘT 2: NỘI DUNG CHÍNH ---
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Hàng tiêu đề + Thời gian
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                noti.title,
                                style: TextStyle(
                                  fontSize: 16,
                                  // Chưa đọc thì chữ đậm, Đã đọc thì chữ thường
                                  fontWeight: isRead
                                      ? FontWeight.w600
                                      : FontWeight.w800,
                                  color: Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              timeStr,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 6),

                        // Nội dung tin nhắn
                        Text(
                          noti.body,
                          style: TextStyle(
                            fontSize: 14,
                            // Chưa đọc thì màu đen rõ, Đã đọc thì màu xám
                            color: isRead
                                ? Colors.grey.shade600
                                : Colors.black87,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // --- CỘT 3: CHẤM XANH (Chỉ hiện khi chưa đọc) ---
                  if (!isRead)
                    Container(
                      margin: const EdgeInsets.only(left: 10, top: 15),
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Color(0xFF2260FF),
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          ),
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

  // 1. Lấy màu nền nhạt cho icon (VD: Tin nhắn -> Xanh nhạt)
  Color _getColorByType(String type) {
    switch (type) {
      case 'CHAT':
        return const Color(0xFFE3F2FD);
      case 'ANNOUNCEMENT':
      case 'COMMENT':
      case 'REACTION':
        return const Color(0xFFE8F5E9);
      case 'TASK':
        return const Color(0xFFFFF3E0);
      case 'LEAVE_REQUEST':
        return const Color(0xFFF3E5F5);
      default:
        return const Color(0xFFFFEBEE);
    }
  }

  // 2. Lấy hình Icon tương ứng
  IconData _getIconByType(String type) {
    switch (type) {
      case 'CHAT':
        return Icons.chat_bubble_outline;
      case 'ANNOUNCEMENT':
        return Icons.campaign_outlined;
      case 'COMMENT':
        return Icons.forum_outlined;
      case 'REACTION':
        return Icons.favorite_border;
      case 'TASK':
        return Icons.assignment_outlined;
      case 'LEAVE_REQUEST':
        return Icons.flight_takeoff;
      default:
        return Icons.notifications_none;
    }
  }

  // 3. Lấy màu đậm cho Icon chính
  Color _getIconColorByType(String type) {
    switch (type) {
      case 'CHAT':
        return Colors.blue;
      case 'ANNOUNCEMENT':
      case 'COMMENT':
      case 'REACTION':
      case 'TASK':
        return Colors.orange;
      case 'LEAVE_REQUEST':
        return Colors.purple;
      default:
        return Colors.red;
    }
  }
}
