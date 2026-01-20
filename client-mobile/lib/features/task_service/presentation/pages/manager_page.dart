// D:\officesync\client-mobile\lib\features\task_service\presentation\pages\manager_page.dart

import 'package:flutter/material.dart';
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
  bool loading = true;
  List<TaskDepartment> managedDepartments = [];

  int? filterDeptId;
  int? filterStaffId;
  TaskStatus? filterStatus;
  DateTime? filterDate;
  bool showAllAssigned = false;

  late TaskStompService _taskStompService; // 1. Khai báo biến

  // Keys để mở Menu thủ công (giúp hiệu ứng Flash Border hoạt động)
  final GlobalKey<PopupMenuButtonState<int?>> _deptMenuKey = GlobalKey();
  final GlobalKey<PopupMenuButtonState<int?>> _staffMenuKey = GlobalKey();
  final GlobalKey<PopupMenuButtonState<TaskStatus?>> _statusMenuKey =
      GlobalKey();

  final Color colorBlue = const Color(0xFF2260FF);
  final Color colorWhite = const Color(0xFFFFFFFF);
  final Color colorBlack = const Color(0xFF000000);
  final Color colorGreen = const Color(0xFF4EE375);
  final Color colorOrange = const Color(0xFFFFA322);
  final Color colorBg = const Color(0xFFF3F5F9);

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
    _setupRealtime(); // 2. Gọi hàm thiết lập Real-time
  }

  // 3. Hàm thiết lập logic Real-time
  void _setupRealtime() {
    _taskStompService = TaskStompService(
      onTaskReceived: (data) {
        if (mounted) {
          setState(() {
            fetchTasks(); // Tải lại danh sách để đồng bộ với DB
          });

          // Kiểm tra xem đây là hành động XÓA hay TẠO MỚI
          if (data is Map && data['action'] == 'DELETE') {
          } else {}
        }
      },
    );
    _taskStompService.connect();
  }

  @override
  void dispose() {
    _taskStompService.disconnect(); // 4. Ngắt kết nối khi đóng trang
    _tabController.dispose();
    super.dispose();
  }

  // --- LOGIC DATA (Giữ nguyên) ---
  Future<void> _initializeSessionAndData() async {
    setState(() => loading = true);
    try {
      // SỬA TẠI ĐÂY: Bỏ "if (TaskSession().userId == null)"
      // Phải luôn gọi API này để đảm bảo TaskSession khớp với X-User-Id hiện tại
      final profileResp = await api.get('${ApiClient.taskUrl}/tasks/me');

      if (profileResp.data != null) {
        final newUser = TaskUser.fromJson(
          Map<String, dynamic>.from(profileResp.data),
        );
        TaskSession().setSession(newUser);

        // Debug để kiểm tra ID đã nhảy sang Pele (10) chưa
        debugPrint(
          "Session Updated: UserID=${TaskSession().userId} | Name=${newUser.fullName}",
        );
      }

      // Sau khi có Session chuẩn, mới tiếp tục lấy dữ liệu khác
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
        final rawStaffs = (usersResp.data as List)
            .map((e) => TaskUser.fromJson(Map<String, dynamic>.from(e)))
            .toList();

        allStaffs = rawStaffs
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

  // chức năng lọc logic để phân tách ngày giữa màn hình Thống kê và màn hình Danh sách.
  List<TaskModel> _getFilteredTasks() {
    final int currentId = TaskSession().userId ?? 0;

    // Lấy danh sách cơ sở
    List<TaskModel> baseList = _tabController.index == 0
        ? tasks.where((t) => t.assigneeId == currentId).toList()
        : tasks
              .where(
                (t) => t.creatorId == currentId && t.assigneeId != currentId,
              )
              .toList();

    var filtered = baseList.where((t) {
      bool matchDept = filterDeptId == null || t.departmentId == filterDeptId;
      bool matchStaff = filterStaffId == null || t.assigneeId == filterStaffId;
      bool matchStatus = filterStatus == null || t.status == filterStatus;

      // QUAN TRỌNG: Chỉ lọc ngày cho List Task khi người dùng đã bấm "View All"
      bool matchDate = true;
      if (_tabController.index == 1 && !showAllAssigned) {
        matchDate = true; // Hiện 5 task mới nhất bất kể ngày tháng
      } else {
        matchDate =
            filterDate == null ||
            (t.dueDate.month == filterDate!.month &&
                t.dueDate.year == filterDate!.year);
      }

      return matchDept && matchStaff && matchStatus && matchDate;
    }).toList();

    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colorBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: colorBlue),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'MANAGEMENT',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: colorBlue,
            fontSize: 30,
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: colorWhite,
              borderRadius: BorderRadius.circular(25),
            ),
            child: Row(
              children: [
                _buildTabBtn("My Job", 0),
                _buildTabBtn("Task Assigned", 1),
              ],
            ),
          ),
          Expanded(
            child: _tabController.index == 0
                ? _buildMyJobTab()
                : _buildAssignedTab(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreateTask,
        backgroundColor: colorBlue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // --- TAB 1 & 2 (Đã cập nhật Filter Bar) ---
  Widget _buildMyJobTab() {
    final filtered = _getFilteredTasks();
    return Column(
      children: [
        _buildFilterBar(),
        Expanded(
          child: loading
              ? Center(child: CircularProgressIndicator(color: colorBlue))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (c, i) => _buildCard(filtered[i], i + 1),
                ),
        ),
      ],
    );
  }

  Widget _buildAssignedTab() {
    final int currentId = TaskSession().userId ?? 0;

    // 1. LOGIC TÍNH TOÁN BÁO CÁO: Luôn luôn lọc theo filterDate (nếu có)
    final reportTasks = tasks.where((t) {
      // Chỉ lấy task mình giao cho người khác
      bool isAssignedByMe =
          t.creatorId == currentId && t.assigneeId != currentId;

      // Lọc chính xác theo tháng/năm của filterDate
      bool matchDate = true;
      if (filterDate != null) {
        matchDate =
            t.dueDate.month == filterDate!.month &&
            t.dueDate.year == filterDate!.year;
      }
      return isAssignedByMe && matchDate;
    }).toList();

    // Tính toán các chỉ số dựa trên reportTasks (đã lọc đúng tháng)
    int total = reportTasks.length;
    int todo = reportTasks.where((t) => t.status == TaskStatus.TODO).length;
    int ip = reportTasks
        .where((t) => t.status == TaskStatus.IN_PROGRESS)
        .length;
    int done = reportTasks.where((t) => t.status == TaskStatus.DONE).length;

    double getP(int v) => total == 0 ? 0 : (v / total) * 100;

    // 2. LOGIC DANH SÁCH HIỂN THỊ (LIST TASK):
    // Nếu chưa bấm View All, hiển thị 5 task mới nhất (không quan tâm tháng)
    // Nếu đã bấm View All, hiển thị theo bộ lọc của người dùng
    final allFiltered = _getFilteredTasks();
    final displayTasks = showAllAssigned
        ? allFiltered
        : allFiltered.take(5).toList();

    return Column(
      children: [
        _buildFilterBar(), // Thanh lọc sẽ hiện nút Lịch ở màn hình Stats
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!showAllAssigned) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Text(
                      "Reports and Statistics",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // Bảng số liệu: Sẽ nhảy về 0 nếu tháng được chọn không có task
                  _buildStatsBox(total, todo, ip, done),
                  const SizedBox(height: 30),
                  _buildCustomPercentChart(
                    getP(todo).round(),
                    getP(ip).round(),
                    getP(done).round(),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => setState(() => showAllAssigned = true),
                      child: Text(
                        "View all",
                        style: TextStyle(
                          color: colorBlue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  // Header của danh sách khi bấm View All
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "List task",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () =>
                              setState(() => showAllAssigned = false),
                        ),
                      ],
                    ),
                  ),
                ],
                // Hiển thị danh sách task
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: displayTasks.length,
                  itemBuilder: (c, i) => _buildCard(displayTasks[i], i + 1),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // để kiểm soát hiển thị các nút dựa trên biến showAllAssigned---
  Widget _buildFilterBar() {
    bool isAssignedTab = _tabController.index == 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          // BÊN TRÁI: Chỉ hiện Chips khi ở My Job HOẶC khi đã bấm View All ở Assigned
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (!isAssignedTab || showAllAssigned) ...[
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
                  ] else if (isAssignedTab &&
                      !showAllAssigned &&
                      filterDate != null)
                    // Chỉ hiện chip ngày ở màn hình Stats để biết đang xem tháng nào
                    _buildActiveChip(
                      "${filterDate!.month}/${filterDate!.year}",
                      () => setState(() => filterDate = null),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // BÊN PHẢI: LOGIC HIỂN THỊ NÚT
          if (isAssignedTab && !showAllAssigned) ...[
            // TRƯỜNG HỢP 1: Màn hình Statistics (Chỉ hiện nút Lịch)
            FlashBorderWrapper(
              borderRadius: BorderRadius.circular(50),
              borderColor: colorBlue,
              onTap: _selectFilterDate,
              child: _circularIconContainer(Icons.calendar_month),
            ),
          ] else ...[
            // TRƯỜNG HỢP 2: Màn hình My Job hoặc màn hình View All của Assigned
            if (isAssignedTab) ...[
              _buildDeptMenu(),
              const SizedBox(width: 8),
              _buildStaffMenu(),
              const SizedBox(width: 8),
            ],
            FlashBorderWrapper(
              borderRadius: BorderRadius.circular(50),
              borderColor: colorBlue,
              onTap: _selectFilterDate,
              child: _circularIconContainer(Icons.calendar_month),
            ),
            const SizedBox(width: 8),
            _buildStatusMenu(),
          ],
        ],
      ),
    );
  }

  // --- CÁC NÚT MENU CỤ THỂ ---

  Widget _buildDeptMenu() {
    return Theme(
      data: Theme.of(context).copyWith(cardColor: colorWhite),
      child: PopupMenuButton<int?>(
        key: _deptMenuKey,
        onSelected: (id) => setState(() => filterDeptId = id),
        itemBuilder: (context) => [
          const PopupMenuItem(value: null, child: Text("All Dept")),
          ...managedDepartments.map(
            (d) => PopupMenuItem(value: d.id, child: Text(d.name)),
          ),
        ],
        child: FlashBorderWrapper(
          borderRadius: BorderRadius.circular(50),
          borderColor: colorBlue,
          onTap: () => _deptMenuKey.currentState?.showButtonMenu(),
          child: _circularIconContainer(Icons.groups_outlined),
        ),
      ),
    );
  }

  Widget _buildStaffMenu() {
    return Theme(
      data: Theme.of(context).copyWith(cardColor: colorWhite),
      child: PopupMenuButton<int?>(
        key: _staffMenuKey,
        onSelected: (id) => setState(() => filterStaffId = id),
        itemBuilder: (context) => [
          const PopupMenuItem(value: null, child: Text("All Staff")),
          ...allStaffs.map(
            (u) => PopupMenuItem(value: u.id, child: Text(u.fullName)),
          ),
        ],
        child: FlashBorderWrapper(
          borderRadius: BorderRadius.circular(50),
          borderColor: colorBlue,
          onTap: () => _staffMenuKey.currentState?.showButtonMenu(),
          child: _circularIconContainer(
            Icons.person_outline,
          ), // Icon Staff theo hình bạn gửi
        ),
      ),
    );
  }

  Widget _buildStatusMenu() {
    return Theme(
      data: Theme.of(context).copyWith(cardColor: colorWhite),
      child: PopupMenuButton<TaskStatus?>(
        key: _statusMenuKey,
        color: colorWhite,
        onSelected: (s) => setState(() => filterStatus = s),
        itemBuilder: (context) => [
          const PopupMenuItem(value: null, child: Text("All Status")),
          ...[TaskStatus.TODO, TaskStatus.IN_PROGRESS, TaskStatus.DONE].map(
            (s) => PopupMenuItem(
              value: s,
              child: Text(s.name.replaceAll('_', ' ')),
            ),
          ),
        ],
        child: FlashBorderWrapper(
          borderRadius: BorderRadius.circular(50),
          borderColor: colorBlue,
          onTap: () => _statusMenuKey.currentState?.showButtonMenu(),
          child: _circularIconContainer(Icons.trending_up),
        ),
      ),
    );
  }

  // --- HELPER WIDGETS ---
  Widget _circularIconContainer(IconData icon) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: colorWhite,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color(0xFFFFFFFF),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        icon,
        color: colorBlue,
        size: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildActiveChip(String label, VoidCallback onClear) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorWhite,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: colorBlue.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: colorBlue,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onClear,
            child: Icon(Icons.close, size: 14, color: colorBlue),
          ),
        ],
      ),
    );
  }

  // (Các hàm _buildStatsBox, _buildCustomPercentChart, _buildCard, _buildTabBtn giữ nguyên như code trước của bạn)
  Widget _buildStatsBox(int total, int todo, int ip, int done) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorWhite,
        borderRadius: BorderRadius.circular(25),
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
            color: colorBlue,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    ),
  );

  Widget _buildCustomPercentChart(int todoP, int ipP, int doneP) {
    const double chartHeight = 180;
    const double axisBottom = 40.0;
    return Container(
      height: 250,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // --- TRỤC TUNG (Oy - %) ---
          Positioned(
            left: 15,
            top: -25,
            child: const Text(
              "%",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          // Mũi tên trục Oy (Đã chỉnh để dính sát)
          Positioned(
            left: 24, // Dịch trái 1 chút để tâm mũi tên khớp với thanh dọc 2px
            top: -12,
            child: Icon(Icons.arrow_drop_up, size: 24, color: colorBlack),
          ),
          Positioned(
            left: 35,
            top: 0,
            bottom: axisBottom,
            child: Container(width: 2, color: colorBlack),
          ),

          // --- CÁC VẠCH CHIA (Y-axis Ticks) ---
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
                      Container(width: 6, height: 1.5, color: colorBlack),
                    ],
                  ),
                ),
              )
              .toList(),

          // --- TRỤC HOÀNH (Ox - Status) ---
          // Đường kẻ ngang (Đã giảm 'right' từ 25 xuống 18 để thanh dài ra, dính vào mũi tên)
          Positioned(
            left: 35,
            right:
                18, // GIẢM THÔNG SỐ NÀY để thanh trục dài ra chạm vào mũi tên
            bottom: axisBottom,
            child: Container(height: 2, color: colorBlack),
          ),
          // Mũi tên trục Ox
          Positioned(
            right: 5,
            bottom:
                axisBottom - 11, // Căn giữa theo chiều dọc với thanh trục 2px
            child: Icon(Icons.arrow_right, size: 24, color: colorBlack),
          ),
          Positioned(
            right: 0,
            bottom: axisBottom - 30,
            child: const Text(
              "Status",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ),

          // --- CỘT DỮ LIỆU ---
          Positioned(
            left: 55,
            right: 45,
            bottom: axisBottom + 2,
            top: 10,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _bar(todoP, colorBlue),
                _bar(ipP, colorOrange),
                _bar(doneP, colorGreen),
              ],
            ),
          ),

          // --- NHÃN DƯỚI CHÂN CỘT ---
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
    width: 35,
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
              fontSize: 9,
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

  Future<void> _selectFilterDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: colorBlue, // Màu chủ đạo (nút, ngày chọn)
              onPrimary: colorWhite, // Chữ trên nền primary
              surface: colorWhite, // Nền của bảng lịch
              onSurface: colorBlack, // Chữ trên nền trắng
            ),
            dialogBackgroundColor:
                colorWhite, // Nền trắng cho toàn bộ hộp thoại
          ),
          child: child!,
        );
      },
    );
    if (d != null) setState(() => filterDate = d);
  }

  Widget _buildCard(TaskModel task, int index) {
    return FlashBorderWrapper(
      borderRadius: BorderRadius.circular(25),
      borderColor: colorBlue,
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => TaskDetailDialog(
          task: task,
          currentUserId: TaskSession().userId!,
          role: 'MANAGER',
          onRefresh: fetchTasks,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.fromLTRB(12, 8, 16, 16),
        decoration: BoxDecoration(
          color: colorWhite,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "#$index",
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Expanded(
                  child: Text(
                    task.title,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: colorBlack,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _buildSmallTag(task.priorityText, task.priorityColor),
                const SizedBox(width: 6),
                _buildSmallTag(task.statusText, task.statusColor),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              task.description,
              style: const TextStyle(color: Color(0xFF000000), fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Department: ${task.departmentName ?? '-'}",
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        "Creator: ${task.creatorName ?? '-'} | Assignee: ${task.assigneeName ?? '-'}",
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "Start: ${task.createdAt.toLocal().toString().split(" ").first}",
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "Due: ${task.dueDate.toLocal().toString().split(" ").first}",
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTabBtn(String label, int index) {
    bool isSelected = _tabController.index == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _tabController.animateTo(index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? colorBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? colorWhite : colorBlue,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  void _openCreateTask() async {
    final res = await showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Cho phép modal chiếm nhiều diện tích
      backgroundColor:
          Colors.transparent, // Để thấy bo góc của Container bên trong
      builder: (_) => CreateTaskDialog(
        role: 'MANAGER',
        currentUserId: TaskSession().userId!,
      ),
    );
    if (res == true) fetchTasks();
  }
}

// --- WIDGET HỖ TRỢ HIỆU ỨNG FLASH BORDER (Sao chép từ Admin Page) ---
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
  Widget build(BuildContext context) {
    return GestureDetector(
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
}
