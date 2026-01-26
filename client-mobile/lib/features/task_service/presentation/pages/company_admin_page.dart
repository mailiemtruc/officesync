// lib/features/task_service/presentation/pages/company_admin_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/api/api_client.dart';
import '../../data/models/task_model.dart';
import '../../data/models/task_user.dart';
import '../../widgets/create_task_dialog.dart';
import '../../widgets/task_detail_dialog.dart';
import '../../data/task_session.dart';
import '../../data/models/task_department.dart';
// [MỚI] Import Skeleton
import '../../widgets/task_card_skeleton.dart';

class CompanyAdminPage extends StatefulWidget {
  const CompanyAdminPage({super.key});
  @override
  State<CompanyAdminPage> createState() => _CompanyAdminPageState();
}

class _CompanyAdminPageState extends State<CompanyAdminPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiClient api = ApiClient();
  List<TaskModel> tasks = [];
  bool loading = true;
  List<TaskDepartment> departments = [];

  final GlobalKey<PopupMenuButtonState<int?>> _deptMenuKey = GlobalKey();
  final GlobalKey<PopupMenuButtonState<TaskStatus?>> _statusMenuKey =
      GlobalKey();

  int? filterDeptId;
  DateTime? filterListDate;
  TaskStatus? filterStatus;

  final Color primaryColor = const Color(0xFF2260FF);
  final Color backgroundColor = const Color(0xFFF9F9F9);
  final Color tabBgColor = const Color(0x72E6E5E5);
  final Color labelGray = const Color(0xFF655F5F);
  final Color colorOrange = const Color(0xFFFFA322);
  final Color colorGreen = const Color(0xFF4EE375);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _initializeSessionAndData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ... (Giữ nguyên các hàm _initializeSessionAndData, fetchTasks, _getFilteredTasks, build, _buildHeader, _buildTabs, _buildTabItem, _buildFilterBar, _buildStatisticsTab...) ...
  Future<void> _initializeSessionAndData() async {
    setState(() => loading = true);
    try {
      if (TaskSession().userId == null) {
        final profileResp = await api.get('${ApiClient.taskUrl}/tasks/me');
        if (profileResp.data != null) {
          TaskSession().setSession(
            TaskUser.fromJson(Map<String, dynamic>.from(profileResp.data)),
          );
        }
      }
      final depsResp = await api.get('${ApiClient.taskUrl}/tasks/departments');
      setState(() {
        departments = (depsResp.data as List)
            .map((e) => TaskDepartment.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      });
      await fetchTasks();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> fetchTasks() async {
    try {
      final resp = await api.get('${ApiClient.taskUrl}/tasks');
      final List data = resp.data as List;
      setState(() {
        tasks = data
            .map((e) => TaskModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      });
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  List<TaskModel> _getFilteredTasks() {
    return tasks.where((t) {
      bool matchDept = filterDeptId == null || t.departmentId == filterDeptId;
      bool matchStatus = filterStatus == null || t.status == filterStatus;
      bool matchDate =
          filterListDate == null ||
          (t.createdAt.month == filterListDate!.month &&
              t.createdAt.year == filterListDate!.year);
      return matchDept && matchStatus && matchDate;
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                const SizedBox(height: 20),
                _buildHeader(),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _buildTabs(),
                ),
                const SizedBox(height: 16),
                if (_tabController.index == 0) _buildFilterBar(),
                const SizedBox(height: 12),
                Expanded(
                  child: _tabController.index == 0
                      ? _buildListTaskTab()
                      : _buildStatisticsTab(),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreateTask,
        backgroundColor: primaryColor,
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Icon(
                PhosphorIcons.caretLeft(PhosphorIconsStyle.bold),
                color: primaryColor,
                size: 24,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Text(
            'COMPANY ADMIN',
            style: TextStyle(
              color: primaryColor,
              fontSize: 24,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: tabBgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _buildTabItem(
            label: 'List Task',
            isActive: _tabController.index == 0,
            onTap: () => _tabController.animateTo(0),
          ),
          _buildTabItem(
            label: 'Reports & Statistics',
            isActive: _tabController.index == 1,
            onTap: () => _tabController.animateTo(1),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                    ),
                  ]
                : [],
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? primaryColor : const Color(0xFFB2AEAE),
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontFamily: 'Inter',
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (filterDeptId != null)
                    _buildActiveChip(
                      departments.firstWhere((d) => d.id == filterDeptId).name,
                      () => setState(() => filterDeptId = null),
                    ),
                  if (filterListDate != null)
                    _buildActiveChip(
                      "${filterListDate!.month}/${filterListDate!.year}",
                      () => setState(() => filterListDate = null),
                    ),
                  if (filterStatus != null)
                    _buildActiveChip(
                      filterStatus!.name.replaceAll('_', ' '),
                      () => setState(() => filterStatus = null),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          _buildDeptMenu(),
          const SizedBox(width: 8),
          _buildCircularBtn(Icons.calendar_month, _selectFilterDate),
          const SizedBox(width: 8),
          _buildStatusMenu(),
        ],
      ),
    );
  }

  // --- [CẬP NHẬT] Thay CircularProgressIndicator bằng Skeleton ---
  Widget _buildListTaskTab() {
    final filteredList = _getFilteredTasks();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "LIST TASKS",
              style: TextStyle(
                color: labelGray,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                fontFamily: 'Inter',
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
        Expanded(
          child: loading
              ? _buildLoadingState() // <--- Sử dụng Skeleton
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  itemCount: filteredList.length,
                  itemBuilder: (c, i) => _buildTaskCard(filteredList[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildStatisticsTab() {
    final statsTasks = tasks.where((t) {
      if (filterListDate == null) return true;
      return t.createdAt.month == filterListDate!.month &&
          t.createdAt.year == filterListDate!.year;
    }).toList();

    int total = statsTasks.length;
    int todo = statsTasks.where((t) => t.status == TaskStatus.TODO).length;
    int ip = statsTasks.where((t) => t.status == TaskStatus.IN_PROGRESS).length;
    int done = statsTasks.where((t) => t.status == TaskStatus.DONE).length;
    double getP(int count) => total == 0 ? 0 : (count / total) * 100;

    if (loading)
      return _buildLoadingState(); // Thêm skeleton cho cả tab thống kê nếu cần

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "REPORTS & STATISTICS",
                      style: TextStyle(
                        color: Color(0xFF655F5F),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      filterListDate == null
                          ? "Showing: All time"
                          : "Month: ${DateFormat('MM/yyyy').format(filterListDate!)}",
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                _buildCircularBtn(Icons.calendar_month, _selectFilterDate),
              ],
            ),
          ),
          _buildStatsBox(total, todo, ip, done),
          const SizedBox(height: 30),
          _buildCustomPercentChart(
            getP(todo).round(),
            getP(ip).round(),
            getP(done).round(),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // --- [MỚI] Hàm tạo List Skeleton ---
  Widget _buildLoadingState() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => const TaskCardSkeleton(),
    );
  }

  // ... (Giữ nguyên các hàm card, nút bấm, biểu đồ...) ...
  Widget _buildTaskCard(TaskModel task) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 10,
            offset: Offset(0, 2),
            spreadRadius: 2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => TaskDetailDialog(
              task: task,
              currentUserId: TaskSession().userId!,
              role: 'COMPANY_ADMIN',
              onRefresh: fetchTasks,
            ),
          ),
          borderRadius: BorderRadius.circular(10),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Container(
                  width: 6,
                  decoration: BoxDecoration(
                    color: task.statusColor,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(10),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                task.title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'Inter',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            _buildSmallTag(task.statusText, task.statusColor),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          task.description,
                          style: const TextStyle(
                            color: Color(0xFF52525B),
                            fontSize: 13,
                            fontFamily: 'Inter',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Due: ${DateFormat('dd/MM/yyyy').format(task.dueDate)}",
                              style: const TextStyle(
                                color: Color(0xFFA1A1AA),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              task.priorityText,
                              style: TextStyle(
                                color: task.priorityColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCircularBtn(IconData icon, VoidCallback onTap) {
    return FlashBorderWrapper(
      borderRadius: BorderRadius.circular(50),
      borderColor: primaryColor,
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: primaryColor, size: 20),
      ),
    );
  }

  Widget _buildDeptMenu() => Theme(
    data: Theme.of(
      context,
    ).copyWith(popupMenuTheme: const PopupMenuThemeData(color: Colors.white)),
    child: PopupMenuButton<int?>(
      key: _deptMenuKey,
      color: Colors.white,
      onSelected: (id) => setState(() => filterDeptId = id),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: null,
          child: Text("All Departments", style: TextStyle(color: Colors.black)),
        ),
        ...departments.map(
          (d) => PopupMenuItem(
            value: d.id,
            child: Text(d.name, style: const TextStyle(color: Colors.black)),
          ),
        ),
      ],
      child: _buildCircularBtn(
        Icons.groups_outlined,
        () => _deptMenuKey.currentState?.showButtonMenu(),
      ),
    ),
  );

  Widget _buildStatusMenu() => Theme(
    data: Theme.of(
      context,
    ).copyWith(popupMenuTheme: const PopupMenuThemeData(color: Colors.white)),
    child: PopupMenuButton<TaskStatus?>(
      key: _statusMenuKey,
      color: Colors.white,
      onSelected: (s) => setState(() => filterStatus = s),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: null,
          child: Text("All Status", style: TextStyle(color: Colors.black)),
        ),
        ...[TaskStatus.TODO, TaskStatus.IN_PROGRESS, TaskStatus.DONE].map(
          (s) => PopupMenuItem(
            value: s,
            child: Text(
              s.name.replaceAll('_', ' '),
              style: const TextStyle(color: Colors.black),
            ),
          ),
        ),
      ],
      child: _buildCircularBtn(
        Icons.trending_up,
        () => _statusMenuKey.currentState?.showButtonMenu(),
      ),
    ),
  );

  Widget _buildStatsBox(int total, int todo, int ip, int done) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        children: [
          _statRow("Total task:", total),
          _statRow("Todo:", todo),
          _statRow("In Progress:", ip),
          _statRow("Done:", done),
        ],
      ),
    );
  }

  Widget _statRow(String label, int value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Text(
          "$value",
          style: TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    ),
  );

  Widget _buildSmallTag(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
    ),
  );
  Widget _buildActiveChip(String label, VoidCallback onClear) => Container(
    margin: const EdgeInsets.only(right: 6),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: primaryColor.withOpacity(0.3)),
    ),
    child: Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: onClear,
          child: Icon(Icons.close, size: 14, color: primaryColor),
        ),
      ],
    ),
  );

  Future<void> _selectFilterDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: Theme.of(
          context,
        ).copyWith(colorScheme: ColorScheme.light(primary: primaryColor)),
        child: child!,
      ),
    );
    if (d != null) setState(() => filterListDate = d);
  }

  Widget _buildCustomPercentChart(int todoP, int ipP, int doneP) {
    const double chartHeight = 180;
    const double axisBottom = 40.0;
    return Container(
      height: 250,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 15,
            top: -25,
            child: const Text(
              "%",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          Positioned(
            left: 24,
            top: -12,
            child: Icon(Icons.arrow_drop_up, size: 24, color: Colors.black),
          ),
          Positioned(
            left: 35,
            top: 0,
            bottom: axisBottom,
            child: Container(width: 2, color: Colors.black),
          ),
          ...[100, 80, 60, 40, 20, 0]
              .map(
                (val) => Positioned(
                  left: 5,
                  bottom: (val / 100) * chartHeight + axisBottom - 7,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 25,
                        child: Text(
                          "$val",
                          style: const TextStyle(fontSize: 9),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Container(width: 6, height: 1.5, color: Colors.black),
                    ],
                  ),
                ),
              )
              .toList(),
          Positioned(
            left: 35,
            right: 18,
            bottom: axisBottom,
            child: Container(height: 2, color: Colors.black),
          ),
          Positioned(
            right: 5,
            bottom: axisBottom - 11,
            child: Icon(Icons.arrow_right, size: 24, color: Colors.black),
          ),
          Positioned(
            right: 0,
            bottom: axisBottom - 30,
            child: const Text(
              "Status",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ),
          Positioned(
            left: 55,
            right: 45,
            bottom: axisBottom + 2,
            top: 10,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _bar(todoP, primaryColor),
                _bar(ipP, colorOrange),
                _bar(doneP, colorGreen),
              ],
            ),
          ),
          Positioned(
            left: 55,
            right: 45,
            bottom: axisBottom - 25,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [_label("Todo"), _label("In Progress"), _label("Done")],
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String t) => SizedBox(
    width: 60,
    child: Text(
      t,
      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
      textAlign: TextAlign.center,
    ),
  );
  Widget _bar(int p, Color c) => Container(
    width: 40,
    height: p == 0 ? 1 : (p / 100) * 180,
    decoration: BoxDecoration(
      color: c,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
    ),
    alignment: Alignment.center,
    child: p > 5
        ? Text(
            "$p",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          )
        : null,
  );

  void _openCreateTask() async {
    final res = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateTaskDialog(
        role: 'COMPANY_ADMIN',
        currentUserId: TaskSession().userId!,
      ),
    );
    if (res == true) fetchTasks();
  }
}

class FlashBorderWrapper extends StatefulWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final VoidCallback onTap;
  final Color borderColor;
  const FlashBorderWrapper({
    super.key,
    required this.child,
    required this.borderRadius,
    required this.onTap,
    required this.borderColor,
  });
  @override
  State<FlashBorderWrapper> createState() => _FlashBorderWrapperState();
}

class _FlashBorderWrapperState extends State<FlashBorderWrapper> {
  bool _showBorder = false;
  void _triggerFlash() {
    if (mounted) {
      setState(() => _showBorder = true);
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _showBorder = false);
      });
    }
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: _triggerFlash,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: widget.borderRadius,
        border: Border.all(
          color: _showBorder ? widget.borderColor : Colors.transparent,
          width: 2,
        ),
      ),
      child: widget.child,
    ),
  );
}
