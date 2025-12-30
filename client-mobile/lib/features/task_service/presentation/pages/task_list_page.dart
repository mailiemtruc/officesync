import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/config/app_colors.dart';
import '../../data/models/task_model.dart';
import '../../widgets/task_card.dart';
import 'create_task_page.dart';

class TaskListPage extends StatefulWidget {
  const TaskListPage({super.key});

  @override
  State<TaskListPage> createState() => _TaskListPageState();
}

class _TaskListPageState extends State<TaskListPage> {
  int _currentTab = 0; // 0: My Tasks, 1: Assigned by Me
  final TextEditingController _searchController = TextEditingController();
  String _userRole = 'STAFF'; //STAFF or MANAGER orCOMPANY_ADMIN 

  // Mock Data
  final List<TaskModel> _allTasks = [
    TaskModel(
      id: '1',
      title: 'Review Project X',
      description: 'Check the latest commit on Git.',
      dueDate: DateTime.now().add(const Duration(days: 2)),
      priority: TaskPriority.high,
      status: TaskStatus.in_progress,
      assigneeName: 'Nguyen Van A',
    ),
    TaskModel(
      id: '2',
      title: 'Fix Login API',
      description: 'Server returns 500 error.',
      dueDate: DateTime.now().add(const Duration(days: 1)),
      priority: TaskPriority.medium,
      status: TaskStatus.todo,
      assigneeName: 'Le Thi B',
    ),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Nhận Role từ Dashboard truyền sang
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is String) {
      setState(() {
        _userRole = args;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Logic phân quyền hiển thị
    bool isStaff = _userRole == 'STAFF';
    bool isManager = _userRole == 'MANAGER';
    bool isAdmin = _userRole == 'COMPANY_ADMIN';

    String pageTitle = 'STAFF';
    if (isManager) pageTitle = 'MANAGER';
    if (isAdmin) pageTitle = 'COMPANY ADMIN';

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                const SizedBox(height: 20),
                _buildHeader(context, pageTitle),
                const SizedBox(height: 24),

                // --- PHẦN TABS (CHỈ HIỆN VỚI MANAGER VÀ ADMIN) ---
                if (!isStaff)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAEBEE),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          _buildTabItem("My Tasks", 0),
                          _buildTabItem("Assigned by Me", 1),
                        ],
                      ),
                    ),
                  ),

                if (!isStaff) const SizedBox(height: 24),

                // --- THANH TÌM KIẾM ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _buildSearchBar(),
                ),
                const SizedBox(height: 20),

                // --- DANH SÁCH CÔNG VIỆC ---
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: _allTasks.length,
                    itemBuilder: (context, index) {
                      return TaskCard(
                        task: _allTasks[index],
                        onTap: () {
                          // TODO: Mở chi tiết công việc
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

      // --- NÚT TẠO (CHỈ HIỆN VỚI MANAGER VÀ ADMIN) ---
      floatingActionButton: !isStaff
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        CreateTaskPage(currentUserRole: _userRole),
                  ),
                );
              },
              backgroundColor: AppColors.primary,
              shape: const CircleBorder(),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null, // Nhân viên không có nút này
    );
  }

  Widget _buildTabItem(String title, int index) {
    final bool isSelected = _currentTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentTab = index),
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                    ),
                  ]
                : [],
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: TextStyle(
              color: isSelected ? AppColors.primary : const Color(0xFFB2AEAE),
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontFamily: 'Inter',
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              PhosphorIcons.caretLeft(PhosphorIconsStyle.bold),
              color: AppColors.primary,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Center(
              child: Text(
                title,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Inter',
                ),
              ),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 45,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search tasks...',
          hintStyle: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 14),
          prefixIcon: Icon(
            PhosphorIcons.magnifyingGlass(),
            color: const Color(0xFF757575),
            size: 20,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }
}
