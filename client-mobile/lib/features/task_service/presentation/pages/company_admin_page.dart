// D:\officesync\client-mobile\lib\features\task_service\presentation\pages\company_admin_page.dart

import 'package:flutter/material.dart';
import '../../../../core/api/api_client.dart';
import '../../data/models/task_model.dart';
import '../../data/models/task_user.dart';
import '../../widgets/create_task_dialog.dart';
import '../../widgets/task_detail_dialog.dart';
import '../../data/task_session.dart';
import '../../data/models/task_department.dart';

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

  // Keys để mở Menu thủ công khi click (giúp hiệu ứng Flash Border hoạt động)
  final GlobalKey<PopupMenuButtonState<int?>> _deptMenuKey = GlobalKey();
  final GlobalKey<PopupMenuButtonState<TaskStatus?>> _statusMenuKey =
      GlobalKey();

  int? filterDeptId;
  DateTime? filterListDate;
  TaskStatus? filterStatus;

  final Color colorBlue = const Color(0xFF2260FF);
  final Color colorWhite = const Color(0xFFFFFFFF);
  final Color colorBlack = const Color(0xFF000000);
  final Color colorGreen = const Color(0xFF4EE375);
  final Color colorOrange = const Color(0xFFFFA322);
  final Color colorBg = const Color.fromARGB(255, 238, 241, 251);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _initializeSessionAndData();
  }

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
    }).toList();
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
          'COMPANY ADMIN',
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
                _buildTabBtn("List Task", 0),
                _buildTabBtn("Reports & Statistics", 1),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildListTaskTab(), _buildStatisticsTab()],
            ),
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

  // --- TAB 1: LIST TASK (Lọc động bên trái, nút bên phải) ---
  Widget _buildListTaskTab() {
    final filteredList = _getFilteredTasks();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      if (filterDeptId != null)
                        _buildActiveFilterChip(
                          departments
                              .firstWhere((d) => d.id == filterDeptId)
                              .name,
                          () => setState(() => filterDeptId = null),
                        ),
                      if (filterListDate != null)
                        _buildActiveFilterChip(
                          "${filterListDate!.month}/${filterListDate!.year}",
                          () => setState(() => filterListDate = null),
                        ),
                      if (filterStatus != null)
                        _buildActiveFilterChip(
                          filterStatus!.name.replaceAll('_', ' '),
                          () => setState(() => filterStatus = null),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // BÊN PHẢI: 3 nút chức năng
              _buildDeptDropdown(),
              const SizedBox(width: 8),
              FlashBorderWrapper(
                borderRadius: BorderRadius.circular(50),
                borderColor: colorBlue,
                onTap: _selectFilterDate,
                child: _circularIconContainer(Icons.calendar_month),
              ),
              const SizedBox(width: 8),
              _buildStatusDropdown(),
            ],
          ),
        ),
        Expanded(
          child: loading
              ? Center(child: CircularProgressIndicator(color: colorBlue))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredList.length,
                  itemBuilder: (c, i) => _buildCard(filteredList[i], i + 1),
                ),
        ),
      ],
    );
  }

  Widget _buildActiveFilterChip(String label, VoidCallback onClear) {
    return GestureDetector(
      onTap: onClear,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colorWhite,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: colorBlue.withOpacity(0.3)),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 2)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: colorBlue,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.close, size: 14, color: colorBlue),
          ],
        ),
      ),
    );
  }

  Widget _buildDeptDropdown() {
    return Theme(
      data: Theme.of(context).copyWith(
        cardColor: colorWhite,
        popupMenuTheme: PopupMenuThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        hoverColor: colorBlue.withOpacity(0.05),
      ),
      child: PopupMenuButton<int?>(
        key: _deptMenuKey,
        // SỬ DỤNG THUỘC TÍNH NÀY để làm trắng toàn bộ nền menu xổ xuống
        color: colorWhite,
        onSelected: (id) => setState(() => filterDeptId = id),
        offset: const Offset(0, 45),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        itemBuilder: (context) => [
          PopupMenuItem(
            value: null,
            child: Text(
              "All Departments",
              style: TextStyle(color: colorBlack, fontSize: 14),
            ),
          ),
          ...departments.map(
            (d) => PopupMenuItem(
              value: d.id,
              child: Text(
                d.name,
                style: TextStyle(color: colorBlack, fontSize: 14),
              ),
            ),
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

  // --- DROP DOWN TRẠNG THÁI (Nền trắng, chữ đen) ---
  Widget _buildStatusDropdown() {
    return Theme(
      data: Theme.of(context).copyWith(cardColor: colorWhite),
      child: PopupMenuButton<TaskStatus?>(
        key: _statusMenuKey,
        color: colorWhite,
        onSelected: (s) => setState(() => filterStatus = s),
        offset: const Offset(0, 45),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        itemBuilder: (context) => [
          PopupMenuItem(
            value: null,
            child: Text(
              "All Status",
              style: TextStyle(color: colorBlack, fontSize: 14),
            ),
          ),
          ...[TaskStatus.TODO, TaskStatus.IN_PROGRESS, TaskStatus.DONE].map(
            (s) => PopupMenuItem(
              value: s,
              child: Text(
                s.name.replaceAll('_', ' '),
                style: TextStyle(color: colorBlack, fontSize: 14),
              ),
            ),
          ),
        ],
        child: FlashBorderWrapper(
          borderRadius: BorderRadius.circular(50),
          borderColor: colorBlue,
          onTap: () => _statusMenuKey.currentState
              ?.showButtonMenu(), // Kích hoạt sổ xuống
          child: _circularIconContainer(Icons.trending_up),
        ),
      ),
    );
  }

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
    if (d != null) setState(() => filterListDate = d);
  }

  // --- CARD UI (Hiệu ứng viền Flash khi click) ---
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
          role: 'COMPANY_ADMIN',
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
              style: TextStyle(fontSize: 13, color: colorBlack),
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

  // --- STATISTICS TAB (Giữ nguyên) ---
  Widget _buildStatisticsTab() {
    final filteredTasks = tasks.where((t) {
      if (filterListDate == null) return true;
      return t.createdAt.month == filterListDate!.month &&
          t.createdAt.year == filterListDate!.year;
    }).toList();

    int total = filteredTasks.length;
    int todo = filteredTasks.where((t) => t.status == TaskStatus.TODO).length;
    int ip = filteredTasks
        .where((t) => t.status == TaskStatus.IN_PROGRESS)
        .length;
    int done = filteredTasks.where((t) => t.status == TaskStatus.DONE).length;
    double getP(int count) => total == 0 ? 0 : (count / total) * 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start, // Để tiêu đề nằm bên trái
      children: [
        // BỘ LỌC
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: filterListDate != null
                      ? _buildActiveFilterChip(
                          "${filterListDate!.month}/${filterListDate!.year}",
                          () => setState(() => filterListDate = null),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
              const SizedBox(width: 10),
              FlashBorderWrapper(
                borderRadius: BorderRadius.circular(50),
                borderColor: colorBlue,
                onTap: _selectFilterDate,
                child: _circularIconContainer(Icons.calendar_month),
              ),
            ],
          ),
        ),

        // NỘI DUNG CHÍNH
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Text(
                    "Reports and Statistics",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                _buildStatsBox(total, todo, ip, done), // Bảng thông số mới
                const SizedBox(height: 30),
                _buildCustomPercentChart(
                  getP(todo).round(),
                  getP(ip).round(),
                  getP(done).round(),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

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

  Widget _buildMonthYearFilterStats() {
    String txt = filterListDate == null
        ? "mm/yyyy"
        : "${filterListDate!.month}/${filterListDate!.year}";
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (d != null) setState(() => filterListDate = d);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: colorWhite,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              txt,
              style: TextStyle(color: colorBlue, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 10),
            Icon(Icons.calendar_month, color: colorBlue),
          ],
        ),
      ),
    );
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
          // --- TRỤC TUNG (Oy - %) ---
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
            left: 24, // Khớp với thanh dọc
            top: -12,
            child: Icon(Icons.arrow_drop_up, size: 24, color: colorBlack),
          ),
          Positioned(
            left: 35,
            top: 0,
            bottom: axisBottom,
            child: Container(width: 2, color: colorBlack),
          ),

          // --- VẠCH CHIA ---
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
          Positioned(
            left: 35,
            right: 18, // Để thanh dính vào mũi tên
            bottom: axisBottom,
            child: Container(height: 2, color: colorBlack),
          ),
          // Mũi tên trục Ox
          Positioned(
            right: 5,
            bottom: axisBottom - 11,
            child: Icon(Icons.arrow_right, size: 24, color: colorBlack),
          ),
          // Nhãn Status
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

          // --- NHÃN CHÂN CỘT ---
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

  // Widget hỗ trợ vẽ nhãn chữ cho chart
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
    height: p == 0 ? 1 : (p / 100) * 200,
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

  Widget _statTxt(String label, int value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 18, color: Colors.black),
        children: [
          TextSpan(
            text: label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const TextSpan(text: " "),
          TextSpan(
            text: "$value",
            style: TextStyle(color: colorBlue, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    ),
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

// --- WIDGET HỖ TRỢ HIỆU ỨNG FLASH BORDER (0.5s) ---
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
    widget.onTap(); // Gọi hàm thực thi khi bấm (ví dụ: mở menu, mở dialog)
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
