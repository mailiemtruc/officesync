import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/api/api_client.dart';
import '../../data/models/task_model.dart';
import '../../widgets/task_detail_dialog.dart';
import '../../data/task_session.dart';
import '../../data/models/task_user.dart';
import '../../data/network/task_stomp_service.dart';

class StaffPage extends StatefulWidget {
  const StaffPage({super.key});

  @override
  State<StaffPage> createState() => _StaffPageState();
}

class _StaffPageState extends State<StaffPage> {
  final ApiClient api = ApiClient();
  List<TaskModel> tasks = [];
  bool loading = true;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  // Lọc
  TaskStatus? selectedStatus; // Null tương đương với 'All'
  bool showOverdueOnly = false;

  late TaskStompService _taskStompService;

  // Màu sắc chuẩn theo my_requests_page
  final Color primaryColor = const Color(0xFF2260FF);
  final Color backgroundColor = const Color(0xFFF9F9F9);
  final Color textSecondary = const Color(0xFF9CA3AF);
  final Color labelGray = const Color(0xFF655F5F);

  @override
  void initState() {
    super.initState();
    _initializeSessionAndData();
    _setupRealtime();
  }

  void _setupRealtime() {
    _taskStompService = TaskStompService(
      onTaskReceived: (data) {
        if (mounted) fetchTasks();
      },
    );
    _taskStompService.connect();
  }

  @override
  void dispose() {
    _taskStompService.disconnect();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeSessionAndData() async {
    setState(() => loading = true);
    try {
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
      if (mounted) {
        setState(() {
          tasks = data
              .map((e) => TaskModel.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        });
      }
    } catch (e) {
      debugPrint("Error fetch: $e");
    }
  }

  List<TaskModel> _getFilteredTasks() {
    return tasks.where((t) {
      // 1. Lọc theo Status
      bool matchStatus = selectedStatus == null || t.status == selectedStatus;

      // 2. Lọc theo Overdue
      bool matchOverdue = true;
      if (showOverdueOnly) {
        final now = DateTime.now();
        matchOverdue = t.status != TaskStatus.DONE && t.dueDate.isBefore(now);
      }

      // 3. Lọc theo Search Query (Title)
      bool matchSearch = t.title.toLowerCase().contains(_searchQuery);

      return matchStatus && matchOverdue && matchSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _getFilteredTasks();

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
                _buildFilterRow(),
                const SizedBox(height: 20),
                _buildStatusTabs(),
                const SizedBox(height: 24),
                _buildSectionLabel("LIST TASKS"),
                const SizedBox(height: 12),
                Expanded(
                  child: loading
                      ? _buildLoadingState()
                      : RefreshIndicator(
                          onRefresh: fetchTasks,
                          color: primaryColor,
                          child: filteredList.isEmpty
                              ? _buildEmptyState()
                              : ListView.builder(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 8,
                                  ),
                                  itemCount: filteredList.length,
                                  itemBuilder: (c, i) =>
                                      _buildTaskCard(filteredList[i]),
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
            'STAFF',
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

  // Row lọc Overdue (Thiết kế giống nút Filter của My Requests)
  Widget _buildFilterRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 45,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE0E0E0)),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.trim().toLowerCase();
                  });
                },
                decoration: InputDecoration(
                  hintText: "Search tasks...",
                  hintStyle: const TextStyle(
                    color: Color(0xFF9E9E9E),
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    PhosphorIcons.magnifyingGlass(),
                    color: Colors.grey,
                    size: 20,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  // Nút xóa nhanh text
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = "");
                          },
                        )
                      : null,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => setState(() => showOverdueOnly = !showOverdueOnly),
            child: Container(
              height: 45,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: showOverdueOnly
                    ? const Color(0xFFECF1FF)
                    : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: showOverdueOnly
                      ? primaryColor
                      : const Color(0xFFE0E0E0),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    showOverdueOnly
                        ? PhosphorIconsFill.clockAfternoon
                        : PhosphorIconsRegular.clockAfternoon,
                    color: showOverdueOnly
                        ? primaryColor
                        : const Color(0xFF555252),
                    size: 20,
                  ),
                  if (showOverdueOnly) ...[
                    const SizedBox(width: 8),
                    Text(
                      "Overdue",
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTabs() {
    final statusOptions = [
      {'label': 'All', 'value': null},
      {'label': 'Todo', 'value': TaskStatus.TODO},
      {'label': 'In Progress', 'value': TaskStatus.IN_PROGRESS},
      {'label': 'Done', 'value': TaskStatus.DONE},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: statusOptions.map((opt) {
          final isSelected = selectedStatus == opt['value'];
          return GestureDetector(
            onTap: () =>
                setState(() => selectedStatus = opt['value'] as TaskStatus?),
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white
                    : const Color(0xFFE5E5E5).withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [],
              ),
              child: Text(
                opt['label'] as String,
                style: TextStyle(
                  color: isSelected ? primaryColor : textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: TextStyle(
            color: labelGray,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            fontFamily: 'Inter',
          ),
        ),
      ),
    );
  }

  Widget _buildTaskCard(TaskModel task) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _showTaskDetail(task),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Thanh màu trạng thái bên trái
                Container(width: 6, color: task.statusColor),
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
                                  color: Colors.black,
                                  fontFamily: 'Inter',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildStatusBadge(task),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          task.description,
                          style: const TextStyle(
                            color: Color(0xFF52525B),
                            fontSize: 13,
                            height: 1.4,
                            fontFamily: 'Inter',
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
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
                                fontFamily: 'Inter',
                              ),
                            ),
                            Text(
                              task.priorityText,
                              style: TextStyle(
                                color: task.priorityColor.withOpacity(0.7),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Inter',
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

  Widget _buildStatusBadge(TaskModel task) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: task.statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        task.statusText,
        style: TextStyle(
          color: task.statusColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          fontFamily: 'Inter',
        ),
      ),
    );
  }

  void _showTaskDetail(TaskModel task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TaskDetailDialog(
        task: task,
        currentUserId: TaskSession().userId ?? 0,
        role: 'STAFF',
        onRefresh: fetchTasks,
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            PhosphorIcons.clipboardText(),
            size: 64,
            color: const Color(0xFFE5E7EB),
          ),
          const SizedBox(height: 16),
          const Text(
            "No tasks found",
            style: TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
