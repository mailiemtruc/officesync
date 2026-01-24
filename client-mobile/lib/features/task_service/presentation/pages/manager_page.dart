// D:\officesync\client-mobile\lib\features\task_service\presentation\pages\manager_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/api/api_client.dart';
import '../../data/models/task_model.dart';
import '../../data/models/task_user.dart';
import '../../data/models/task_department.dart';
import '../../widgets/create_task_dialog.dart';
import '../../widgets/task_detail_dialog.dart';
import '../../data/task_session.dart';
import '../../data/network/task_stomp_service.dart';

class ManagerPage extends StatefulWidget {
  const ManagerPage({super.key});
  @override
  State<ManagerPage> createState() => _ManagerPageState();
}

class _ManagerPageState extends State<ManagerPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiClient api = ApiClient();

  List<TaskModel> tasks = [];
  List<TaskUser> allStaffs = [];
  List<TaskDepartment> managedDepartments = [];
  bool loading = true;
  bool showAllAssigned = false;

  // Bộ lọc logic
  int? filterDeptId;
  int? filterStaffId;
  TaskStatus? filterStatus;
  DateTime? filterDate;

  // Keys để mở Menu thủ công cho hiệu ứng Flash Border
  final GlobalKey<PopupMenuButtonState<int?>> _deptMenuKey = GlobalKey();
  final GlobalKey<PopupMenuButtonState<int?>> _staffMenuKey = GlobalKey();
  final GlobalKey<PopupMenuButtonState<TaskStatus?>> _statusMenuKey =
      GlobalKey();

  late TaskStompService _taskStompService;

  // Màu sắc chuẩn
  final Color primaryColor = const Color(0xFF2260FF);
  final Color backgroundColor = const Color(0xFFF9F9F9);
  final Color tabBgColor = const Color(0x72E6E5E5);
  final Color colorOrange = const Color(0xFFFFA322);
  final Color colorGreen = const Color(0xFF4EE375);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() => showAllAssigned = false);
      }
      setState(() {});
    });
    _initializeSessionAndData();
    _setupRealtime();
  }

  void _setupRealtime() {
    _taskStompService = TaskStompService(
      onTaskReceived: (data) {
        if (mounted) setState(() => fetchTasks());
      },
    );
    _taskStompService.connect();
  }

  @override
  void dispose() {
    _taskStompService.disconnect();
    _tabController.dispose();
    super.dispose();
  }

  // --- LOGIC DATA ---
  Future<void> _initializeSessionAndData() async {
    setState(() => loading = true);
    try {
      final profileResp = await api.get('${ApiClient.taskUrl}/tasks/me');
      if (profileResp.data != null) {
        TaskSession().setSession(
          TaskUser.fromJson(Map<String, dynamic>.from(profileResp.data)),
        );
      }
      final int currentId = TaskSession().userId ?? 0;
      final depsResp = await api.get('${ApiClient.taskUrl}/tasks/departments');
      final usersResp = await api.get(
        '${ApiClient.taskUrl}/tasks/users/suggestion',
      );

      setState(() {
        final allDepts = (depsResp.data as List)
            .map((e) => TaskDepartment.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        managedDepartments = allDepts
            .where((d) => d.managerId == currentId)
            .toList();
        final managedDeptIds = managedDepartments.map((d) => d.id).toSet();
        allStaffs = (usersResp.data as List)
            .map((e) => TaskUser.fromJson(Map<String, dynamic>.from(e)))
            .where(
              (u) =>
                  managedDeptIds.contains(u.departmentId) && u.id != currentId,
            )
            .toList();
      });
      await fetchTasks();
    } catch (e) {
      debugPrint("Init Error: $e");
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
    final int currentId = TaskSession().userId ?? 0;
    List<TaskModel> baseList = _tabController.index == 0
        ? tasks.where((t) => t.assigneeId == currentId).toList()
        : tasks
              .where(
                (t) => t.creatorId == currentId && t.assigneeId != currentId,
              )
              .toList();

    return baseList.where((t) {
      bool matchDept = filterDeptId == null || t.departmentId == filterDeptId;
      bool matchStaff = filterStaffId == null || t.assigneeId == filterStaffId;
      bool matchStatus = filterStatus == null || t.status == filterStatus;

      bool matchDate = true;
      if (_tabController.index == 1 && !showAllAssigned) {
        matchDate = true; // Không lọc ngày ở màn hình thống kê thu gọn
      } else {
        matchDate =
            filterDate == null ||
            (t.dueDate.month == filterDate!.month &&
                t.dueDate.year == filterDate!.year);
      }
      return matchDept && matchStaff && matchStatus && matchDate;
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
                _buildFilterBar(), // Thanh nút lọc tròn
                const SizedBox(height: 12),
                Expanded(
                  child: _tabController.index == 0
                      ? _buildMyJobTab()
                      : _buildAssignedTab(),
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
            'MANAGEMENT',
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
            label: 'My Job',
            isActive: _tabController.index == 0,
            onTap: () => _tabController.animateTo(0),
          ),
          _buildTabItem(
            label: 'Task Assigned',
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
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFamily: 'Inter',
            ),
          ),
        ),
      ),
    );
  }

  // --- THANH NÚT LỌC TRÒN ---
  Widget _buildFilterBar() {
    bool isAssignedTab = _tabController.index == 1;
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
                      managedDepartments
                          .firstWhere((d) => d.id == filterDeptId)
                          .name,
                      () => setState(() => filterDeptId = null),
                    ),
                  if (filterStaffId != null)
                    _buildActiveChip(
                      allStaffs
                          .firstWhere((u) => u.id == filterStaffId)
                          .fullName,
                      () => setState(() => filterStaffId = null),
                    ),
                  if (filterDate != null)
                    _buildActiveChip(
                      "${filterDate!.month}/${filterDate!.year}",
                      () => setState(() => filterDate = null),
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
          if (isAssignedTab && !showAllAssigned) ...[
            _buildCircularBtn(Icons.calendar_month, _selectFilterDate),
          ] else ...[
            if (isAssignedTab) ...[
              _buildDeptMenu(),
              const SizedBox(width: 8),
              _buildStaffMenu(),
              const SizedBox(width: 8),
            ],
            _buildCircularBtn(Icons.calendar_month, _selectFilterDate),
            const SizedBox(width: 8),
            _buildStatusMenu(),
          ],
        ],
      ),
    );
  }

  Widget _buildMyJobTab() {
    final filtered = _getFilteredTasks();
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "LIST TASKS",
              style: TextStyle(
                color: Color(0xFF655F5F),
                fontSize: 14,
                fontWeight: FontWeight.w700,
                fontFamily: 'Inter',
              ),
            ),
          ),
        ),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (c, i) => _buildTaskCard(filtered[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildAssignedTab() {
    final int currentId = TaskSession().userId ?? 0;
    final reportTasks = tasks.where((t) {
      bool isAssignedByMe =
          t.creatorId == currentId && t.assigneeId != currentId;
      bool matchDate =
          filterDate == null ||
          (t.dueDate.month == filterDate!.month &&
              t.dueDate.year == filterDate!.year);
      return isAssignedByMe && matchDate;
    }).toList();

    int total = reportTasks.length;
    int todo = reportTasks.where((t) => t.status == TaskStatus.TODO).length;
    int ip = reportTasks
        .where((t) => t.status == TaskStatus.IN_PROGRESS)
        .length;
    int done = reportTasks.where((t) => t.status == TaskStatus.DONE).length;

    double getP(int v) => total == 0 ? 0 : (v / total) * 100;

    final allFiltered = _getFilteredTasks();
    final displayTasks = showAllAssigned
        ? allFiltered
        : allFiltered.take(5).toList();

    return SingleChildScrollView(
      child: Column(
        children: [
          if (!showAllAssigned) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Reports and Statistics",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
            _buildStatsBox(total, todo, ip, done),
            const SizedBox(height: 30),
            _buildCustomPercentChart(
              getP(todo).round(),
              getP(ip).round(),
              getP(done).round(),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => setState(() => showAllAssigned = true),
                  child: Text(
                    "View all",
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "List Tasks",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => showAllAssigned = false),
                  ),
                ],
              ),
            ),
          ],
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: displayTasks.length,
            itemBuilder: (c, i) => _buildTaskCard(displayTasks[i]),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // --- CÁC NÚT LỌC CIRCULAR ---
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
    data: Theme.of(context).copyWith(
      // Chỉnh popupMenuTheme để đảm bảo nền trắng ở mọi phiên bản Flutter
      popupMenuTheme: const PopupMenuThemeData(color: Colors.white),
    ),
    child: PopupMenuButton<int?>(
      key: _deptMenuKey,
      color: Colors.white, // Đặt màu nền dropdown trắng tinh
      elevation: 4, // Thêm độ đổ bóng để tách biệt với nền trang
      onSelected: (id) => setState(() => filterDeptId = id),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: null,
          child: Text("All Dept", style: TextStyle(color: Colors.black)),
        ),
        ...managedDepartments.map(
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

  Widget _buildStaffMenu() => Theme(
    data: Theme.of(
      context,
    ).copyWith(popupMenuTheme: const PopupMenuThemeData(color: Colors.white)),
    child: PopupMenuButton<int?>(
      key: _staffMenuKey,
      color: Colors.white, // Đặt màu nền dropdown trắng tinh
      elevation: 4,
      onSelected: (id) => setState(() => filterStaffId = id),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: null,
          child: Text("All Staff", style: TextStyle(color: Colors.black)),
        ),
        ...allStaffs.map(
          (u) => PopupMenuItem(
            value: u.id,
            child: Text(
              u.fullName,
              style: const TextStyle(color: Colors.black),
            ),
          ),
        ),
      ],
      child: _buildCircularBtn(
        Icons.person_outline,
        () => _staffMenuKey.currentState?.showButtonMenu(),
      ),
    ),
  );

  Widget _buildStatusMenu() => Theme(
    data: Theme.of(
      context,
    ).copyWith(popupMenuTheme: const PopupMenuThemeData(color: Colors.white)),
    child: PopupMenuButton<TaskStatus?>(
      key: _statusMenuKey,
      color: Colors.white, // Đặt màu nền dropdown trắng tinh
      elevation: 4,
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
  // --- CHART & STATS ---
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
          _statRow("Total tasks:", total),
          _statRow("Todo:", todo),
          _statRow("In Progress:", ip),
          _statRow("Done:", done),
        ],
      ),
    );
  }

  Widget _statRow(String label, int val) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        Text(
          "$val",
          style: TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    ),
  );

  Widget _buildCustomPercentChart(int todoP, int ipP, int doneP) {
    const double chartHeight = 180; // Chiều cao tối đa của cột
    const double axisBottom = 40.0; // Khoảng cách từ đáy stack đến trục Ox

    return Container(
      height: 250,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Nhãn đơn vị % ở đỉnh trục Oy
          Positioned(
            left: 15,
            top: -25,
            child: const Text(
              "%",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          // Mũi tên trục Oy
          Positioned(
            left: 24,
            top: -12,
            child: Icon(Icons.arrow_drop_up, size: 24, color: Colors.black),
          ),
          // Đường kẻ trục Oy
          Positioned(
            left: 35,
            top: 0,
            bottom: axisBottom,
            child: Container(width: 2, color: Colors.black),
          ),

          // Vẽ các vạch chia tỉ lệ và con số (0, 20, 40, 60, 80, 100)
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

          // Đường kẻ trục Ox
          Positioned(
            left: 35,
            right: 18,
            bottom: axisBottom,
            child: Container(height: 2, color: Colors.black),
          ),
          // Mũi tên trục Ox
          Positioned(
            right: 5,
            bottom: axisBottom - 11,
            child: Icon(Icons.arrow_right, size: 24, color: Colors.black),
          ),
          // Nhãn "Status" ở cuối trục Ox
          Positioned(
            right: 0,
            bottom: axisBottom - 30,
            child: const Text(
              "Status",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ),

          // Hiển thị các cột (Bars)
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
          // Hiển thị nhãn dưới chân cột
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

  Widget _bar(int p, Color c) => Container(
    width: 40, // Tăng chiều rộng cột giống Admin
    height: p == 0 ? 1 : (p / 100) * 180,
    decoration: BoxDecoration(
      color: c,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
    ),
    alignment: Alignment.center,
    child: p > 5
        ? Text(
            "$p", // Bỏ dấu % bên trong cột để giống Admin
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          )
        : null,
  );

  Widget _label(String t) => SizedBox(
    width: 60,
    child: Text(
      t,
      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
      textAlign: TextAlign.center,
    ),
  );
  // --- CARD & DIALOGS ---
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
          onTap: () => _openTaskDetail(task),
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
    if (d != null) setState(() => filterDate = d);
  }

  void _openTaskDetail(TaskModel task) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => TaskDetailDialog(
      task: task,
      currentUserId: TaskSession().userId!,
      role: 'MANAGER',
      onRefresh: fetchTasks,
    ),
  );
  void _openCreateTask() async {
    final res = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateTaskDialog(
        role: 'MANAGER',
        currentUserId: TaskSession().userId!,
      ),
    );
    if (res == true) fetchTasks();
  }
}

// --- WIDGET HỖ TRỢ HIỆU ỨNG FLASH BORDER ---
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
