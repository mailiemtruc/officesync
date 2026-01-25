import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// Service & Model
import 'package:officesync/features/notification_service/notification_service.dart';
import '../../models/notification_model.dart';

// Data Sources & APIs
import 'package:officesync/features/hr_service/data/datasources/request_remote_data_source.dart';
import 'package:officesync/features/communication_service/data/newsfeed_api.dart';

// Screens (Đã import đầy đủ các trang đích)
import 'package:officesync/features/chat_service/presentation/pages/chat_detail_screen.dart';
import 'package:officesync/features/communication_service/presentation/pages/post_detail_screen.dart';
import 'package:officesync/features/hr_service/presentation/pages/request_detail_page.dart';
import 'package:officesync/features/hr_service/presentation/pages/manager_request_review_page.dart';
import 'package:officesync/dashboard_screen.dart';

class NotificationListScreen extends StatefulWidget {
  final int userId;
  const NotificationListScreen({super.key, required this.userId});

  @override
  State<NotificationListScreen> createState() => _NotificationListScreenState();
}

class _NotificationListScreenState extends State<NotificationListScreen> {
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;
  final _requestDataSource = RequestRemoteDataSource();

  @override
  void initState() {
    super.initState();
    _loadData();

    // Lắng nghe tin mới realtime
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        if (mounted) {
          setState(() {
            final newNoti = NotificationModel(
              id: DateTime.now().millisecondsSinceEpoch,
              title: message.notification!.title ?? "Thông báo mới",
              body: message.notification!.body ?? "",
              type: message.data['type'] ?? "GENERAL",
              referenceId:
                  int.tryParse(message.data['referenceId'] ?? "0") ?? 0,
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

  // HÀM XỬ LÝ TAP VÀO ITEM
  void _handleNotificationTap(NotificationModel noti) async {
    String type = noti.type;
    int id = noti.referenceId;
    String currentUserId = widget.userId.toString();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      switch (type) {
        // --- REQUEST ---
        case 'REQUEST':
          if (id == 0) throw Exception("Invalid ID");

          final requestModel = await _requestDataSource.getRequestById(
            id.toString(),
            currentUserId,
          );

          if (!mounted) return;
          Navigator.pop(context); // Tắt loading

          if (requestModel != null) {
            bool isMyRequest = requestModel.requesterId == currentUserId;
            if (isMyRequest) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RequestDetailPage(request: requestModel),
                ),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ManagerRequestReviewPage(request: requestModel),
                ),
              );
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Không tìm thấy thông tin đơn này."),
              ),
            );
          }
          break;

        // --- CHAT ---
        case 'CHAT':
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ChatDetailScreen(roomId: id, chatName: noti.title),
            ),
          );
          break;

        // --- NEWSFEED ---
        case 'ANNOUNCEMENT':
        case 'COMMENT':
        case 'REACTION':
          final post = await NewsfeedApi().getPostById(id);
          if (!mounted) return;
          Navigator.pop(context);

          if (post != null) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
            );
          }
          break;

        // --- SYSTEM (SỬA LẠI ĐỂ DÙNG USER PROFILE PAGE) ---
        case 'SYSTEM':
        case 'ROLE_UPDATE':
        case 'DEPARTMENT_UPDATE':
          Navigator.pop(context);
          DashboardScreen.switchTab(context, 2);

          // 3. Đóng trang NotificationListScreen để lộ Dashboard ra
          Navigator.pop(context);
          break;

        // --- DEFAULT ---
        default:
          Navigator.pop(context);
          print("⚠️ Loại thông báo chưa hỗ trợ: $type");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Chưa hỗ trợ loại thông báo: $type")),
          );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Có lỗi xảy ra: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Thêm nền trắng cho sạch
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true, // <--- Dòng quan trọng để đưa chữ vào giữa
        // --- 2. CHỈNH NÚT BACK (Giống các màn hình trước) ---
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
        title: const Text(
          "NOTIFICATIONS",
          style: TextStyle(
            color: Color(0xFF2260FF),
            fontSize: 24, // Kích thước 24 cho đồng bộ
            fontFamily: 'Inter', // Font Inter
            fontWeight: FontWeight.bold,
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

  Widget _buildItem(NotificationModel noti) {
    bool isRead = noti.isRead;
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
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              spreadRadius: 2,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
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
              // 1. Đánh dấu đã đọc
              if (!isRead) {
                NotificationService().markAsRead(noti.id);
                setState(() {
                  final index = _notifications.indexWhere(
                    (e) => e.id == noti.id,
                  );
                  if (index != -1) {
                    // [ĐÃ SỬA] Bây giờ NotificationModel đã có hàm copyWith
                    _notifications[index] = noti.copyWith(isRead: true);
                  }
                });
              }
              // 2. Gọi hàm xử lý chuyển trang
              _handleNotificationTap(noti);
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _getColorByType(noti.type),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getIconByType(noti.type),
                      color: _getIconColorByType(noti.type),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                noti.title,
                                style: TextStyle(
                                  fontSize: 16,
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
                        Text(
                          noti.body,
                          style: TextStyle(
                            fontSize: 14,
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
          Text("No Notifications", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

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
      case 'REQUEST':
        return const Color(0xFFF3E5F5);
      default:
        return const Color(0xFFFFEBEE);
    }
  }

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
      case 'REQUEST':
        return Icons.description_outlined;
      default:
        return Icons.notifications_none;
    }
  }

  Color _getIconColorByType(String type) {
    switch (type) {
      case 'CHAT':
        return Colors.blue;
      case 'ANNOUNCEMENT':
      case 'COMMENT':
      case 'REACTION':
        return Colors.green;
      case 'TASK':
        return Colors.orange;
      case 'REQUEST':
        return Colors.purple;
      default:
        return Colors.red;
    }
  }
}
