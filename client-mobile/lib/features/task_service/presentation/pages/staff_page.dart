// D:\officesync\client-mobile\lib\features\task_service\presentation\pages\staff_page.dart

import 'package:flutter/material.dart';
import '../../../../core/api/api_client.dart';
import '../../data/models/task_model.dart';
import '../../widgets/task_detail_dialog.dart';
import '../../data/task_session.dart';
import '../../data/models/task_user.dart';
import '../../data/network/task_stomp_service.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class StaffPage extends StatefulWidget {
  const StaffPage({super.key});
  @override
  State<StaffPage> createState() => _StaffPageState();
}

class _StaffPageState extends State<StaffPage> {
  final ApiClient api = ApiClient();
  List<TaskModel> tasks = [];
  bool loading = true;
  TaskStatus? selectedStatus;
  bool showOverdueOnly = false;

  late TaskStompService _taskStompService; // 1. Khai báo biến

  // Menu key để kích hoạt hiệu ứng Flash Border
  final GlobalKey<PopupMenuButtonState<TaskStatus?>> _statusMenuKey =
      GlobalKey();

  final Color colorBlue = const Color(0xFF2260FF);
  final Color colorGreen = const Color(0xFF4EE375);
  final Color colorOrange = const Color(0xFFFFA322);
  final Color colorWhite = const Color(0xFFFFFFFF);
  final Color colorBlack = const Color(0xFF000000);
  final Color colorBg = const Color.fromARGB(255, 238, 241, 251);

  @override
  void initState() {
    super.initState();
    _initializeSessionAndData();
    _setupRealtime(); // 2. Gọi hàm thiết lập
  }

  // 3. Logic Real-time cho Staff
  void _setupRealtime() {
    _taskStompService = TaskStompService(
      onTaskReceived: (data) {
        if (mounted) {
          setState(() {
            fetchTasks(); // Staff tự động cập nhật lại List của mình
          });
        }
      },
    );
    _taskStompService.connect();
  }

  @override
  void dispose() {
    _taskStompService.disconnect(); // 4. Ngắt kết nối
    super.dispose();
  }

  Future<void> _initializeSessionAndData() async {
    setState(() => loading = true);
    try {
      // SỬA TẠI ĐÂY: Luôn đồng bộ lại session khi vào trang
      final profileResp = await api.get('${ApiClient.taskUrl}/tasks/me');
      if (profileResp.data != null) {
        TaskSession().setSession(
          TaskUser.fromJson(Map<String, dynamic>.from(profileResp.data)),
        );
      }
      await fetchTasks();
    } catch (e) {
      debugPrint("Staff Init Error: $e");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> fetchTasks() async {
    try {
      final resp = await api.get('${ApiClient.taskUrl}/tasks/mine');
      final List data = resp.data as List;
      setState(() {
        tasks = data
            .map((e) => TaskModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      });
    } catch (e) {
      debugPrint("Error fetch: $e");
    }
  }

  List<TaskModel> _getFilteredTasks() {
    return tasks.where((t) {
      bool matchStatus = selectedStatus == null || t.status == selectedStatus;
      bool matchOverdue = true;
      if (showOverdueOnly) {
        final now = DateTime.now();
        matchOverdue = t.status != TaskStatus.DONE && t.dueDate.isBefore(now);
      }
      return matchStatus && matchOverdue;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _getFilteredTasks();

    return Scaffold(
      backgroundColor: colorBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leadingWidth: 56, // Giống Admin
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Icon(
              PhosphorIcons.caretLeft(
                PhosphorIconsStyle.bold,
              ), // Đổi icon giống Admin
              color: colorBlue,
              size: 24,
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: Text(
          'STAFF',
          style: TextStyle(
            color: colorBlue,
            fontSize: 24, // Đồng bộ size 24
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFilterHeader(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Text(
              "List task",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: colorBlack,
                fontFamily: 'Inter', // Thêm đồng bộ font
              ),
            ),
          ),
          Expanded(
            child: loading
                ? Center(child: CircularProgressIndicator(color: colorBlue))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredList.length,
                    itemBuilder: (c, i) =>
                        _buildCustomTaskCard(filteredList[i], i + 1),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (selectedStatus != null)
                    _buildActiveFilterChip(
                      selectedStatus!.name.replaceAll('_', ' '),
                      () => setState(() => selectedStatus = null),
                    ),
                  if (showOverdueOnly)
                    _buildActiveFilterChip(
                      "Overdue",
                      () => setState(() => showOverdueOnly = false),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          _buildStatusMenu(),
          const SizedBox(width: 8),
          _buildOverdueButton(),
        ],
      ),
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

  Widget _buildStatusMenu() {
    return Theme(
      data: Theme.of(context).copyWith(cardColor: colorWhite),
      child: PopupMenuButton<TaskStatus?>(
        key: _statusMenuKey,
        color: colorWhite,
        onSelected: (s) => setState(() => selectedStatus = s),
        itemBuilder: (context) => [
          PopupMenuItem(
            value: null,
            child: Text("All Status", style: TextStyle(color: colorBlack)),
          ),
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

  Widget _buildOverdueButton() {
    return FlashBorderWrapper(
      borderRadius: BorderRadius.circular(50),
      borderColor: colorBlue,
      onTap: () => setState(() => showOverdueOnly = !showOverdueOnly),
      child: _circularIconContainer(
        Icons.hourglass_bottom,
        active: showOverdueOnly,
      ),
    );
  }

  Widget _circularIconContainer(IconData icon, {bool active = false}) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: active ? colorBlue.withOpacity(0.1) : colorWhite,
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
        color: active ? Colors.red : colorBlue,
        size: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildCustomTaskCard(TaskModel task, int index) {
    return FlashBorderWrapper(
      borderRadius: BorderRadius.circular(25),
      borderColor: colorBlue,
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => TaskDetailDialog(
          task: task,
          currentUserId: TaskSession().userId ?? 0,
          role: 'STAFF',
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

  // ĐÃ ĐỔI TÊN Ở ĐÂY ĐỂ TRÁNH LỖI UNDEFINED_METHOD
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
