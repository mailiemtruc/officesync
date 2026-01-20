import 'package:flutter/material.dart';
import 'package:officesync/features/communication_service/presentation/pages/newsfeed_screen.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'dart:async';
import '../../../../core/config/app_colors.dart';
import 'package:officesync/features/chat_service/presentation/pages/chat_screen.dart';
//import '../../../../communication_service/presentation/pages/newsfeed_screen.dart';

import 'director_company_profile_screen.dart';
import '../../../../core/utils/custom_snackbar.dart';
import 'package:officesync/features/notification_service/presentation/pages/notification_list_screen.dart';

import '../../../../core/api/api_client.dart';
import '../../../task_service/data/models/task_model.dart';
import '../../../task_service/widgets/task_detail_dialog.dart';
import '../../../task_service/data/task_session.dart';

class DirectorHomeView extends StatefulWidget {
  final int currentUserId;
  const DirectorHomeView({super.key, required this.currentUserId});

  @override
  State<DirectorHomeView> createState() => _DirectorHomeViewState();
}

class _DirectorHomeViewState extends State<DirectorHomeView> {
  bool _animate = false;

  // 1. Khai báo biến quản lý dữ liệu Task
  final ApiClient api = ApiClient();
  List<TaskModel> tasks = [];
  bool loadingTasks = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _animate = true);
    });
    // 2. Gọi hàm lấy dữ liệu khi khởi tạo
    fetchTasks();
  }

  // 3. Hàm lấy dữ liệu Task từ Backend
  Future<void> fetchTasks() async {
    try {
      // Gọi endpoint /api/tasks (đã định nghĩa trong TaskController.java)
      final resp = await api.get('${ApiClient.taskUrl}/tasks');
      final List data = resp.data as List;

      if (mounted) {
        setState(() {
          tasks = data
              .map((e) => TaskModel.fromJson(Map<String, dynamic>.from(e)))
              .toList();

          // Sắp xếp Task mới nhất lên đầu (dựa trên createdAt)
          tasks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          loadingTasks = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching tasks for Home: $e");
      if (mounted) setState(() => loadingTasks = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 900;

    return Container(
      color: const Color(0xFFF3F5F9),
      child: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
    );
  }

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAnimatedItem(0, _buildHeader()),
          const SizedBox(height: 30),
          _buildAnimatedItem(1, _buildBlueCard()),
          const SizedBox(height: 30),
          _buildAnimatedItem(2, _buildQuickActions()),
          const SizedBox(height: 35),
          _buildAnimatedItem(3, _buildProgressHeader()),
          const SizedBox(height: 15),
          _buildAnimatedItem(4, _buildAssignedTaskList()),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(40.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAnimatedItem(0, _buildHeader()),
                const SizedBox(height: 40),
                _buildAnimatedItem(1, _buildBlueCard()),
                const SizedBox(height: 40),
                _buildAnimatedItem(2, _buildQuickActions()),
              ],
            ),
          ),
          const SizedBox(width: 40),
          Expanded(
            flex: 6,
            child: Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAnimatedItem(3, _buildProgressHeader()),
                  const SizedBox(height: 20),
                  _buildAnimatedItem(4, _buildAssignedTaskList()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 55,
              height: 55,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                image: const DecorationImage(
                  image: NetworkImage("https://i.pravatar.cc/150?img=68"),
                  fit: BoxFit.cover,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 15),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Hi, Nguyen Van C',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 18,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Director - ABC Tech',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 14,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        Row(
          children: [
            _buildCircleIcon(PhosphorIconsBold.bell, () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => NotificationListScreen(
                    userId: widget
                        .currentUserId, // Truyền ID user vào màn hình thông báo
                  ),
                ),
              );
            }),
            const SizedBox(width: 12),
            _buildCircleIcon(PhosphorIconsBold.chatCircleDots, () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ChatScreen()),
              );
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildBlueCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFCAD6FF),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2260FF).withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'New Announcements',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Year-end party preparation & schedule',
            style: TextStyle(
              color: Color(0xFF1E293B),
              fontSize: 20,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              CustomSnackBar.show(
                context,
                title: "News",
                message: "Showing details...",
              );
            },
            child: Row(
              children: [
                const Text(
                  'Read more',
                  style: TextStyle(
                    color: Color(0xFF1E293B),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  PhosphorIconsBold.arrowRight,
                  size: 16,
                  color: const Color(0xFF1E293B),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildActionItem("Config", PhosphorIconsBold.gear, () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const DirectorCompanyProfileScreen(),
            ),
          ).then((_) {
            setState(() {});
          });
        }),

        _buildActionItem("Note", PhosphorIconsBold.notePencil, () {
          CustomSnackBar.show(
            context,
            title: "Note",
            message: "Director notes feature.",
          );
        }),

        _buildActionItem("Assign Task", PhosphorIconsBold.clipboardText, () {
          // SỬA TẠI ĐÂY: Thay thế CustomSnackBar bằng lệnh điều hướng
          Navigator.pushNamed(context, '/tasks', arguments: 'COMPANY_ADMIN');
        }),

        _buildActionItem("News", PhosphorIconsBold.newspaper, () {
          // 👇 Thay thế đoạn CustomSnackBar cũ bằng đoạn Navigator này:
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const NewsfeedScreen()),
          );
        }),
      ],
    );
  }

  Widget _buildProgressHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // SỬA TẠI ĐÂY: Bao bọc Text bằng InkWell để bắt sự kiện chạm
        InkWell(
          onTap: () {
            Navigator.pushNamed(context, '/tasks', arguments: 'COMPANY_ADMIN');
          },
          borderRadius: BorderRadius.circular(8),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Text(
              'My Tasks',
              style: TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 24,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.pushNamed(context, '/tasks', arguments: 'COMPANY_ADMIN');
          },
          child: const Text(
            "View all",
            style: TextStyle(
              color: Color(0xFF2260FF),
              fontSize: 13,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionItem(String label, IconData icon, VoidCallback onTap) {
    return Column(
      children: [
        Material(
          color: const Color(0xFFE0E7FF),
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: 68,
              height: 68,
              alignment: Alignment.center,
              child: Icon(icon, color: const Color(0xFF1E293B), size: 30),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: 75,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // 4. CẬP NHẬT HÀM HIỂN THỊ DANH SÁCH TASK
  Widget _buildAssignedTaskList() {
    if (loadingTasks) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF2260FF)),
      );
    }

    if (tasks.isEmpty) {
      return const Center(
        child: Text(
          "No tasks assigned yet.",
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final latestTasks = tasks.take(3).toList();

    return Column(
      children: latestTasks.map((task) {
        // Định nghĩa màu trạng thái dựa trên yêu cầu của bạn
        Color statusBgColor;
        switch (task.status) {
          case TaskStatus.TODO:
            statusBgColor = const Color(0xFF2260FF);
            break;
          case TaskStatus.IN_PROGRESS:
            statusBgColor = const Color(0xFFFFA322);
            break;
          case TaskStatus.DONE:
          case TaskStatus.REVIEW:
            statusBgColor = const Color(0xFF4EE375);
            break;
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildTaskProgressItem(
            title: task.title,
            status: task.statusText,
            statusColor: statusBgColor, // Màu nền theo trạng thái
            assignee: task.assigneeName ?? "No Assignee",
            startDate: task.createdAt,
            dueDate: task.dueDate,
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => TaskDetailDialog(
                  task: task,
                  currentUserId: widget.currentUserId,
                  role: 'COMPANY_ADMIN',
                  onRefresh: fetchTasks,
                ),
              );
            },
          ),
        );
      }).toList(),
    );
  }

  // 5. GIỮ NGUYÊN KÍCH THƯỚC VÀ STYLE NHƯ TRONG ẢNH
  Widget _buildTaskProgressItem({
    required String title,
    required String status,
    required Color statusColor,
    required String assignee,
    required DateTime startDate,
    required DateTime dueDate,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // TIÊU ĐỀ: Màu 4EE375 theo yêu cầu
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF000000), 
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // TAG TRẠNG THÁI: Nền màu trạng thái, Chữ trắng (ffffff)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color:
                            statusColor, // Màu nền (2260FF, FFA322, hoặc 4EE375)
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status,
                        style: const TextStyle(
                          color: Colors.white, // Chữ trắng ffffff
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),

                    // THÔNG TIN BÊN PHẢI
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'To: $assignee',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        // Ngày tháng trên cùng 1 hàng để tiết kiệm diện tích
                        Text(
                          'S: ${startDate.toLocal().toString().split(" ").first} | D: ${dueDate.toLocal().toString().split(" ").first}',
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCircleIcon(IconData icon, VoidCallback onTap) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Center(
            child: Icon(icon, size: 24, color: const Color(0xFF1E293B)),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedItem(int index, Widget child) {
    return AnimatedSlide(
      offset: _animate ? Offset.zero : const Offset(0, 0.1),
      duration: Duration(milliseconds: 500 + (index * 100)),
      curve: Curves.easeOutQuad,
      child: AnimatedOpacity(
        opacity: _animate ? 1.0 : 0.0,
        duration: Duration(milliseconds: 500 + (index * 100)),
        child: child,
      ),
    );
  }
}
