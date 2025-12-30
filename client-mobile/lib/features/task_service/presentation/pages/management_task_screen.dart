// features/task_service/presentation/pages/management_task_screen.dart
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/config/app_colors.dart';
import '../../data/models/task_model.dart';
import '../../widgets/task_card.dart';
import 'create_task_page.dart';

class ManagementTaskScreen extends StatefulWidget {
  final String userRole; // 'COMPANY_ADMIN' hoặc 'MANAGER'

  const ManagementTaskScreen({super.key, required this.userRole});

  @override
  State<ManagementTaskScreen> createState() => _ManagementTaskScreenState();
}

class _ManagementTaskScreenState extends State<ManagementTaskScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Mock Data
  final List<TaskModel> _allTasks = [
    TaskModel(
      id: '1',
      title: 'Sales Report',
      description: 'Q4 Revenue',
      dueDate: DateTime.now().add(const Duration(days: 1)),
      status: TaskStatus.todo,
      priority: TaskPriority.high,
    ),
    TaskModel(
      id: '2',
      title: 'Marketing Campaign',
      description: 'Banner design',
      dueDate: DateTime.now().add(const Duration(days: 3)),
      status: TaskStatus.in_progress,
      priority: TaskPriority.medium,
    ),
    TaskModel(
      id: '3',
      title: 'Fix Server',
      description: 'Error 500',
      dueDate: DateTime.now(),
      status: TaskStatus.done,
      priority: TaskPriority.high,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    bool isAdmin = widget.userRole == 'COMPANY_ADMIN';

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          isAdmin ? 'COMPANY ADMIN' : 'MANAGEMENT',
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: AppColors.primary,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. Phần Tabs (Chỉ Manager mới cần chia My Job / Assigned, Admin thì xem tất cả hoặc filter)
            if (!isAdmin) _buildManagerTabs(),

            if (isAdmin) const SizedBox(height: 16),

            // 2. Nút Create Task
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            CreateTaskPage(currentUserRole: widget.userRole),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text(
                    "Create Task",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 3. Biểu đồ tiến độ (Statistics Chart)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildStatisticsChart(),
            ),

            const SizedBox(height: 24),

            // 4. Báo cáo đơn từ (Requests Report)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildRequestReportSection(isAdmin),
            ),

            const SizedBox(height: 24),

            // 5. Danh sách Task
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "List Task",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {},
                        child: const Text("See all"),
                      ),
                    ],
                  ),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _allTasks.length,
                    itemBuilder: (context, index) {
                      return TaskCard(task: _allTasks[index], onTap: () {});
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildManagerTabs() {
    return Container(
      height: 45,
      margin: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(25),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.primary,
        tabs: const [
          Tab(text: "My Job"),
          Tab(text: "Task Assigned"),
        ],
      ),
    );
  }

  // Widget Biểu đồ đơn giản (Không cần thư viện ngoài để tránh lỗi pubspec)
  Widget _buildStatisticsChart() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Task Progress",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildBar(
                height: 60,
                label: "Todo",
                color: const Color(0xFF64748B),
              ),
              _buildBar(
                height: 40,
                label: "In Progress",
                color: const Color(0xFFF97316),
              ),
              _buildBar(
                height: 100,
                label: "Done",
                color: const Color(0xFF10B981),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBar({
    required double height,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          width: 30,
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  // Widget Báo cáo đơn từ
  Widget _buildRequestReportSection(bool isAdmin) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(PhosphorIcons.chartBar(), color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                isAdmin
                    ? "Monthly Report (Requests)"
                    : "Daily Report (Requests)",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildReportRow("Total Requests", "12"),
          _buildReportRow("Approved", "8"),
          _buildReportRow("Pending", "4"),
        ],
      ),
    );
  }

  Widget _buildReportRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
