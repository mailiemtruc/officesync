import 'package:flutter/material.dart';
import 'package:officesync/features/communication_service/presentation/pages/newsfeed_screen.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'dart:async';
import '../../../../core/config/app_colors.dart';
import 'package:officesync/features/chat_service/presentation/pages/chat_screen.dart';
import 'director_company_profile_screen.dart';
import '../../../../core/utils/custom_snackbar.dart';
import 'package:officesync/features/notification_service/presentation/pages/notification_list_screen.dart';
import '../../../../core/api/api_client.dart';
import '../../../task_service/data/models/task_model.dart';
import '../../../task_service/widgets/task_detail_dialog.dart';
import '../../../hr_service/data/datasources/employee_remote_data_source.dart';
import '../../../hr_service/data/models/employee_model.dart';
import '../../../../core/utils/user_update_event.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../widgets/skeleton_director_home.dart';

class DirectorHomeView extends StatefulWidget {
  final int currentUserId;
  const DirectorHomeView({super.key, required this.currentUserId});

  @override
  State<DirectorHomeView> createState() => _DirectorHomeViewState();
}

class _DirectorHomeViewState extends State<DirectorHomeView>
    with WidgetsBindingObserver {
  bool _animate = false;
  StreamSubscription? _updateSubscription;
  final ApiClient api = ApiClient();
  List<TaskModel> tasks = [];
  bool loadingTasks = true;
  bool _isFirstLoad = true;

  // [MỚI] Biến User Info
  final EmployeeRemoteDataSource _employeeDataSource =
      EmployeeRemoteDataSource();
  String _fullName = 'Director';
  String _jobTitle = 'Director';
  String? _avatarUrl;
  bool _loadingUserInfo = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // [MỚI]

    // Animation fade
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _animate = true);
    });

    // Gọi hàm load dữ liệu tổng hợp
    _loadAllData();

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _animate = true);
    });

    _updateSubscription = UserUpdateEvent().onUserUpdated.listen((_) {
      print("--> DirectorHomeView: Received update signal. Reloading info...");
      _fetchLatestUserInfo();
    });
  }

  Future<void> _loadAllData() async {
    try {
      // Chạy song song 2 API
      await Future.wait([_fetchLatestUserInfo(), fetchTasks()]);
    } catch (e) {
      debugPrint("⚠️ Lỗi tải dữ liệu: $e");
    } finally {
      // [QUAN TRỌNG] Dù thành công hay thất bại, luôn tắt loading
      if (mounted) {
        setState(() {
          _isFirstLoad = false;
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _updateSubscription?.cancel();
    super.dispose();
  }

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
      // 1. Ưu tiên Local Storage
      String? userInfoStr = await storage.read(key: 'user_info');
      if (userInfoStr != null) {
        final data = jsonDecode(userInfoStr);
        if (data['companyName'] != null) {
          companyName = data['companyName'];
        }
        if (mounted) {
          setState(() {
            _fullName = data['fullName'] ?? _fullName;
            _avatarUrl = data['avatarUrl'] ?? _avatarUrl;
            _jobTitle = "Director • $companyName";
            _loadingUserInfo = false;
          });
        }
      }

      // 2. Gọi API
      final employees = await _employeeDataSource.getEmployees(
        widget.currentUserId.toString(),
      );
      final currentUser = employees.firstWhere(
        (e) => e.id == widget.currentUserId.toString(),
        orElse: () => EmployeeModel(
          id: widget.currentUserId.toString(),
          fullName: 'Director',
          email: '',
          phone: '',
          dateOfBirth: '',
          role: 'COMPANY_ADMIN',
        ),
      );

      try {
        final userJson = currentUser.toJson();
        if (userJson['companyName'] != null) {
          companyName = userJson['companyName'];
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _fullName = currentUser.fullName;
          _avatarUrl = currentUser.avatarUrl;
          _jobTitle = "Director • $companyName";
          _loadingUserInfo = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching director info: $e");
      if (mounted) setState(() => _loadingUserInfo = false);
    }
  }

  Future<void> fetchTasks() async {
    try {
      final resp = await api.get('${ApiClient.taskUrl}/tasks');
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
      debugPrint("Error fetching tasks for Home: $e");
      if (mounted) setState(() => loadingTasks = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 900;

    return RefreshIndicator(
      onRefresh: () async {
        // Khi kéo để refresh thì không cần hiện Skeleton full màn hình nữa
        await _loadAllData();
      },
      color: AppColors.primary,
      child: Container(
        color: const Color(0xFFF3F5F9),
        child: SafeArea(
          bottom: false,
          // [THAY ĐỔI TẠI ĐÂY] Kiểm tra _isFirstLoad
          child: _isFirstLoad
              ? const SkeletonDirectorHome() // Hiện Skeleton
              : (isDesktop
                    ? _buildDesktopLayout()
                    : _buildMobileLayout()), // Hiện nội dung thật
        ),
      ),
    );
  }

  // ... (Layout giữ nguyên)
  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
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
          _buildAnimatedItem(3, _buildProgressHeader()),
          const SizedBox(height: 15),
          _buildAnimatedItem(4, _buildAssignedTaskList()),
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

  // [SỬA] Header hiển thị thông tin thật + Avatar chuẩn
  Widget _buildHeader() {
    final placeholderBgColor = Colors.grey[200];
    final placeholderIconColor = Colors.grey[400];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Container(
                width: 55,
                height: 55,
                decoration: BoxDecoration(
                  color: placeholderBgColor,
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
                          errorBuilder: (_, __, ___) => Center(
                            child: Icon(
                              PhosphorIcons.user(PhosphorIconsStyle.fill),
                              color: placeholderIconColor,
                              size: 28,
                            ),
                          ),
                        )
                      : Center(
                          child: Icon(
                            PhosphorIcons.user(PhosphorIconsStyle.fill),
                            color: placeholderIconColor,
                            size: 28,
                          ),
                        ),
                ),
              ),
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
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
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

  // ... (Giữ nguyên các Widget còn lại)
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
          Navigator.pushNamed(context, '/tasks', arguments: 'COMPANY_ADMIN');
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

  Widget _buildProgressHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
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

  Widget _buildAssignedTaskList() {
    if (loadingTasks)
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF2260FF)),
      );
    if (tasks.isEmpty)
      return const Center(
        child: Text(
          "No tasks assigned yet.",
          style: TextStyle(color: Colors.grey),
        ),
      );
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
            statusColor: statusBgColor,
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
                          'To: $assignee',
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
