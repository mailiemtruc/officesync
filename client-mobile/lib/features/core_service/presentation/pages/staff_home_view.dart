import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'dart:async';
import '../../../../core/config/app_colors.dart';
import 'package:officesync/features/notification_service/presentation/pages/notification_list_screen.dart';
import 'package:officesync/features/communication_service/presentation/pages/newsfeed_screen.dart';
import 'package:officesync/features/chat_service/presentation/pages/chat_screen.dart';
import '../../../note_service/presentation/pages/note_list_screen.dart';
import '../../../../core/api/api_client.dart';
import '../../../task_service/data/models/task_model.dart';
import '../../../task_service/widgets/task_detail_dialog.dart';
import '../../../hr_service/data/datasources/employee_remote_data_source.dart';
import '../../../hr_service/data/models/employee_model.dart';
import '../../../../core/utils/user_update_event.dart';
import '../../../hr_service/presentation/pages/my_requests_page.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../widgets/skeleton_staff_home.dart';
import '../../../../core/utils/custom_snackbar.dart';
import 'package:officesync/features/attendance_service/presentation/pages/attendance_screen.dart';

class StaffHomeView extends StatefulWidget {
  final int currentUserId;
  const StaffHomeView({super.key, required this.currentUserId});

  @override
  State<StaffHomeView> createState() => _StaffHomeViewState();
}

// [MỚI] Thêm WidgetsBindingObserver để phát hiện khi app quay lại
class _StaffHomeViewState extends State<StaffHomeView>
    with WidgetsBindingObserver {
  bool _animate = false;
  bool _isFirstLoad = true;
  final ApiClient api = ApiClient();
  final EmployeeRemoteDataSource _employeeDataSource =
      EmployeeRemoteDataSource(); // [MỚI]

  List<TaskModel> tasks = [];
  bool loadingTasks = true;
  StreamSubscription? _updateSubscription;
  // Biến lưu thông tin user
  String _fullName = 'Loading...';
  String _jobTitle = 'Staff';
  String? _avatarUrl;

  // [MỚI] Biến để xử lý trạng thái đang tải user info
  bool _loadingUserInfo = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // [MỚI] Đăng ký lắng nghe

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _animate = true);
    });

    _loadAllData();

    // [QUAN TRỌNG - MỚI] Đăng ký lắng nghe: Hễ ai gọi notify() là tôi reload ngay
    _updateSubscription = UserUpdateEvent().onUserUpdated.listen((_) {
      print("--> StaffHomeView: Received update signal. Reloading info...");
      _fetchLatestUserInfo();
    });
  }

  Future<void> _loadAllData() async {
    try {
      // Chạy song song 2 API
      await Future.wait([_fetchLatestUserInfo(), fetchTasks()]);
    } catch (e) {
      debugPrint("⚠️ Lỗi tải dữ liệu Staff Home: $e");
    } finally {
      // [QUAN TRỌNG] Luôn tắt Skeleton
      if (mounted) {
        setState(() {
          _isFirstLoad = false;
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // [MỚI] Hủy lắng nghe
    _updateSubscription?.cancel(); // [MỚI] Nhớ hủy lắng nghe để tránh lỗi
    super.dispose();
  }

  // [MỚI] Hàm này chạy khi App được resume hoặc quay lại (để update Avatar nếu vừa sửa)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchLatestUserInfo();
    }
  }

  Future<void> _fetchLatestUserInfo() async {
    final storage = const FlutterSecureStorage();
    String companyName = "OfficeSync";

    try {
      // 1. Đọc từ Storage và CẬP NHẬT UI NGAY (Optimistic UI)
      String? userInfoStr = await storage.read(key: 'user_info');
      Map<String, dynamic> localData = {};

      if (userInfoStr != null) {
        localData = jsonDecode(userInfoStr);
        if (localData['companyName'] != null) {
          companyName = localData['companyName'];
        }

        // [QUAN TRỌNG] Update UI ngay lập tức từ dữ liệu local
        if (mounted) {
          setState(() {
            _fullName = localData['fullName'] ?? _fullName;
            _avatarUrl = localData['avatarUrl'] ?? _avatarUrl;
            _jobTitle = "Staff • $companyName"; // Hiển thị tên công ty ngay
            _loadingUserInfo = false;
          });
        }
      }

      // 2. Sau đó mới gọi API để lấy dữ liệu mới nhất (nếu có mạng)
      final employees = await _employeeDataSource.getEmployees(
        widget.currentUserId.toString(),
      );

      final currentUser = employees.firstWhere(
        (e) => e.id == widget.currentUserId.toString(),
        orElse: () => EmployeeModel(
          id: widget.currentUserId.toString(),
          fullName: 'Staff Member',
          email: '',
          phone: '',
          dateOfBirth: '',
          role: 'STAFF',
        ),
      );

      // Thử lấy companyName mới từ API (nếu backend có trả về)
      try {
        final dynamic userDyn = currentUser;
        if (getDynamicField(userDyn, 'companyName') != null) {
          companyName = getDynamicField(userDyn, 'companyName');
        }
      } catch (_) {}

      // 3. Cập nhật UI lần 2 (nếu dữ liệu API khác local)
      if (mounted) {
        setState(() {
          _fullName = currentUser.fullName;
          _avatarUrl = currentUser.avatarUrl;
          _jobTitle = "Staff • $companyName";
          _loadingUserInfo = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching user info in Home: $e");
      // Dù lỗi API, nhưng nhờ bước 1, UI đã hiển thị đúng tên công ty rồi.
      if (mounted) setState(() => _loadingUserInfo = false);
    }
  }

  // Hàm hỗ trợ lấy field động an toàn
  dynamic getDynamicField(dynamic object, String fieldName) {
    try {
      // Nếu object là Map
      if (object is Map) return object[fieldName];
      // Nếu object là Class, convert sang Json rồi lấy (cách an toàn nhất mà ko sửa Model)
      try {
        return (object.toJson())[fieldName];
      } catch (_) {
        return null;
      }
    } catch (_) {
      return null;
    }
  }

  Future<void> fetchTasks() async {
    try {
      final resp = await api.get('${ApiClient.taskUrl}/tasks/mine');
      final List data = resp.data as List;

      if (mounted) {
        setState(() {
          tasks = data
              .map((e) => TaskModel.fromJson(Map<String, dynamic>.from(e)))
              .toList();
          tasks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          loadingTasks = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching tasks for Staff Home: $e");
      if (mounted) setState(() => loadingTasks = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 900;

    return RefreshIndicator(
      onRefresh: () async {
        // Kéo để refresh thì gọi lại load data (không hiện skeleton full)
        await _loadAllData();
      },
      color: AppColors.primary,
      child: Container(
        color: const Color(0xFFF3F5F9),
        child: SafeArea(
          bottom: false,
          // [THAY ĐỔI TẠI ĐÂY] Logic hiển thị Skeleton
          child: _isFirstLoad
              ? const SkeletonStaffHome() // Đang load lần đầu -> Hiện Skeleton
              : (isDesktop
                    ? _buildDesktopLayout()
                    : _buildMobileLayout()), // Load xong -> Hiện nội dung thật
        ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(), // Giúp UX mượt hơn
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAnimatedItem(0, _buildHeader()),
          const SizedBox(height: 30),
          _buildAnimatedItem(1, _buildBlueCard()),
          const SizedBox(height: 30),
          _buildAnimatedItem(2, _buildQuickActions()),
          const SizedBox(height: 35),
          _buildAnimatedItem(3, _buildMyJobHeader()),
          const SizedBox(height: 15),
          _buildAnimatedItem(4, _buildTaskList()),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
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
                  _buildAnimatedItem(3, _buildMyJobHeader()),
                  const SizedBox(height: 20),
                  _buildAnimatedItem(4, _buildTaskList()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // [SỬA] Cập nhật widget Header để hiện Avatar chuẩn và fallback đẹp
  Widget _buildHeader() {
    final placeholderBgColor = Colors.grey[200];
    final placeholderIconColor = Colors.grey[400];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              // --- AVATAR SECTION ĐÃ SỬA ---
              Container(
                width: 55,
                height: 55,
                decoration: BoxDecoration(
                  color: placeholderBgColor, // Nền xám mặc định
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                      ? Image.network(
                          _avatarUrl!,
                          fit: BoxFit.cover,
                          width: 55,
                          height: 55,
                          // Xử lý khi link ảnh bị lỗi -> hiện icon
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Icon(
                                PhosphorIcons.user(PhosphorIconsStyle.fill),
                                color: placeholderIconColor,
                                size: 28,
                              ),
                            );
                          },
                        )
                      : Center(
                          // Khi không có avatar -> hiện icon
                          child: Icon(
                            PhosphorIcons.user(PhosphorIconsStyle.fill),
                            color: placeholderIconColor,
                            size: 28,
                          ),
                        ),
                ),
              ),
              // -----------------------------
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _loadingUserInfo ? 'Loading...' : 'Hi, $_fullName',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 18,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Hiển thị Phòng ban đã fix
                    Text(
                      _jobTitle,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 14,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            _buildCircleIcon(PhosphorIconsBold.bell, () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      NotificationListScreen(userId: widget.currentUserId),
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

  // ... (Các widget còn lại giữ nguyên code cũ của bạn) ...

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
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              // [THÊM MỚI] Hiển thị thông báo tính năng đang phát triển
              CustomSnackBar.show(
                context,
                title: "Info",
                message: "This feature is under development.",
                isError: true,
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
        _buildActionItem("Request", PhosphorIconsBold.calendarBlank, () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const MyRequestsPage()),
          );
        }),
        _buildActionItem("Note", PhosphorIconsBold.notePencil, () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const NoteListScreen()),
          );
        }),
        _buildActionItem("OT", PhosphorIconsBold.clock, () {
          // [SỬA TẠI ĐÂY] Chuyển sang màn hình Chấm công
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AttendanceScreen()),
          );
        }),
        _buildActionItem("News", PhosphorIconsBold.newspaper, () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const NewsfeedScreen()),
          );
        }),
      ],
    );
  }

  Widget _buildMyJobHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'My Job',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 24,
            fontFamily: 'Inter',
            fontWeight: FontWeight.bold,
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.pushNamed(context, '/tasks', arguments: 'STAFF');
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
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildTaskList() {
    if (loadingTasks) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF2260FF)),
      );
    }
    if (tasks.isEmpty) {
      return const Center(
        child: Text(
          "You have no tasks assigned.",
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    final latestTasks = tasks.take(3).toList();
    return Column(
      children: latestTasks.map((task) {
        Color statusBgColor;
        switch (task.status) {
          case TaskStatus.TODO:
            statusBgColor = const Color(0xFF2260FF);
            break;
          case TaskStatus.IN_PROGRESS:
            statusBgColor = const Color(0xFFFFA322);
            break;
          default:
            statusBgColor = const Color(0xFF4EE375);
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildTaskItem(
            title: task.title,
            status: task.statusText,
            statusColor: statusBgColor,
            assignedBy: task.creatorName ?? "Manager",
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
                  role: 'STAFF',
                  onRefresh: fetchTasks,
                ),
              );
            },
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTaskItem({
    required String title,
    required String status,
    required Color statusColor,
    required String assignedBy,
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'By $assignedBy',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
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
