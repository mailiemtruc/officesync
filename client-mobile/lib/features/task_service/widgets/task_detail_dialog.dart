// lib/features/task_service/widgets/task_detail_dialog.dart

import 'package:flutter/material.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/config/app_colors.dart';
import '../../../../core/utils/custom_snackbar.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../data/models/task_model.dart';
import '../data/models/task_department.dart';
import '../data/models/task_user.dart';

class TaskDetailDialog extends StatefulWidget {
  final TaskModel task;
  final int currentUserId;
  final String role;
  final VoidCallback onRefresh;

  const TaskDetailDialog({
    super.key,
    required this.task,
    required this.currentUserId,
    required this.role,
    required this.onRefresh,
  });

  @override
  State<TaskDetailDialog> createState() => _TaskDetailDialogState();
}

class _TaskDetailDialogState extends State<TaskDetailDialog> {
  final ApiClient api = ApiClient();

  // -- State quản lý form --
  late TextEditingController _titleCtl;
  late TextEditingController _descCtl;
  late TaskStatus _selectedStatus;

  // State cho quyền Edit
  TaskPriority? _selectedPriority;
  DateTime? _dueDate;
  int? _selectedDeptId;
  int? _selectedAssigneeId;

  // Metadata lists
  List<TaskDepartment> departments = [];
  List<TaskUser> allUsers = [];
  List<TaskUser> filteredUsers = [];

  bool _isUpdating = false;
  final Color colorRed = const Color(0xFFEF4444);

  // --- LOGIC PHÂN QUYỀN ---
  bool get _canEditAll {
    if (widget.role == 'COMPANY_ADMIN') return true;
    return widget.currentUserId.toString() == widget.task.creatorId.toString();
  }

  bool get _canDelete => _canEditAll;

  @override
  void initState() {
    super.initState();
    _initData();
    if (_canEditAll) {
      _loadMeta();
    }
  }

  void _initData() {
    _titleCtl = TextEditingController(text: widget.task.title);
    _descCtl = TextEditingController(text: widget.task.description);
    _selectedStatus = widget.task.status;
    _selectedPriority = widget.task.priority;
    _dueDate = widget.task.dueDate;
    _selectedDeptId = widget.task.departmentId;
    _selectedAssigneeId = widget.task.assigneeId;
  }

  Future<void> _loadMeta() async {
    try {
      final depsResp = await api.get('${ApiClient.taskUrl}/tasks/departments');
      final usersResp = await api.get(
        '${ApiClient.taskUrl}/tasks/users/suggestion',
      );

      if (mounted) {
        setState(() {
          final allDepts = (depsResp.data as List)
              .map((e) => TaskDepartment.fromJson(Map<String, dynamic>.from(e)))
              .toList();

          if (widget.role == 'MANAGER') {
            departments = allDepts
                .where((d) => d.managerId == widget.currentUserId)
                .toList();
          } else {
            departments = allDepts;
          }

          final allLoadedUsers = (usersResp.data as List)
              .map((e) => TaskUser.fromJson(Map<String, dynamic>.from(e)))
              .toList();

          allUsers = allLoadedUsers;

          if (_selectedDeptId != null) {
            _filterUsersByDept(_selectedDeptId);
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading metadata: $e');
    }
  }

  void _filterUsersByDept(int? deptId) {
    setState(() {
      _selectedDeptId = deptId;
      filteredUsers = allUsers.where((u) {
        final bool isInDept = u.departmentId?.toString() == deptId?.toString();
        final bool isNotMe = u.id.toString() != widget.currentUserId.toString();
        return isInDept && isNotMe;
      }).toList();
    });
  }

  @override
  void dispose() {
    _titleCtl.dispose();
    _descCtl.dispose();
    super.dispose();
  }

  // --- HÀM XỬ LÝ API ---
  Future<void> _handleDelete() async {
    // [SỬA] Chuyển Dialog sang Tiếng Anh
    bool confirm =
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Confirm Delete"),
            content: const Text(
              "Are you sure you want to delete this task? This action cannot be undone.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  "Delete",
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    try {
      await api.delete('${ApiClient.taskUrl}/tasks/${widget.task.id}');
      widget.onRefresh();
      if (mounted) {
        Navigator.pop(context);
        // [SỬA] Chuyển SnackBar sang Tiếng Anh
        CustomSnackBar.show(
          context,
          title: "Success",
          message: "Task deleted successfully",
          isError: false,
        );
      }
    } catch (e) {
      if (mounted)
        CustomSnackBar.show(
          context,
          title: "Error",
          message: "$e",
          isError: true,
        );
    }
  }

  Future<void> _updateTaskInfo() async {
    setState(() => _isUpdating = true);
    try {
      if (_canEditAll) {
        // [SỬA] Validation sang Tiếng Anh
        if (_titleCtl.text.isEmpty) throw "Title cannot be empty";
        if (_selectedAssigneeId == null) throw "Please select an assignee";
      }

      final payload = {
        'title': _titleCtl.text.trim(),
        'description': _descCtl.text.trim(),
        'status': _selectedStatus.toString().split('.').last,
        if (_canEditAll) ...{
          'priority': _selectedPriority.toString().split('.').last,
          'dueDate': _dueDate?.toIso8601String(),
          'departmentId': _selectedDeptId,
          'assigneeId': _selectedAssigneeId,
        },
      };

      await api.put(
        '${ApiClient.taskUrl}/tasks/${widget.task.id}',
        data: payload,
      );
      widget.onRefresh();

      if (mounted) {
        Navigator.pop(context);
        // [SỬA] SnackBar sang Tiếng Anh
        CustomSnackBar.show(
          context,
          title: "Updated",
          message: "Task updated successfully",
          isError: false,
        );
      }
    } catch (e) {
      if (mounted)
        CustomSnackBar.show(
          context,
          title: "Error",
          message: "$e",
          isError: true,
        );
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Chiều cao 55% màn hình
    final double sheetHeight = MediaQuery.of(context).size.height * 0.55;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        height: sheetHeight,
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              children: [
                const SizedBox(height: 40),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // TITLE
                        _buildLabel("Title"),
                        CustomTextField(
                          controller: _titleCtl,
                          hintText: "Enter title",
                          readOnly: !_canEditAll,
                        ),
                        const SizedBox(height: 15),

                        // DESCRIPTION
                        _buildLabel("Description"),
                        CustomTextField(
                          controller: _descCtl,
                          hintText: "Enter description",
                          readOnly: !_canEditAll,
                          maxLines: 3,
                        ),
                        const SizedBox(height: 15),

                        // STATUS
                        const Text(
                          "Status:",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildStatusDropdown(),

                        const SizedBox(height: 15),
                        const Divider(),

                        // DETAIL FIELDS
                        if (_canEditAll)
                          _buildEditableFields()
                        else
                          _buildReadOnlyFields(),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // ACTIONS
                Row(
                  children: [
                    Expanded(
                      child: CustomButton(
                        text: "Save",
                        onPressed: _isUpdating ? () {} : _updateTaskInfo,
                        backgroundColor: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: CustomButton(
                        text: "Cancel",
                        onPressed: () => Navigator.pop(context),
                        backgroundColor: colorRed,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            if (_canDelete)
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.black87,
                    size: 28,
                  ),
                  onPressed: _handleDelete,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // --- WIDGET CON ---

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.black54,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // [SỬA] Chỉ hiển thị 3 trạng thái: TODO, IN_PROGRESS, DONE
  Widget _buildStatusDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(13),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<TaskStatus>(
          value: _selectedStatus,
          isExpanded: true,
          // Sử dụng List cụ thể thay vì TaskStatus.values để loại bỏ REVIEW hoặc các trạng thái khác
          items: [TaskStatus.TODO, TaskStatus.IN_PROGRESS, TaskStatus.DONE]
              .map(
                (s) => DropdownMenuItem(
                  value: s,
                  child: Text(s.name.replaceAll('_', ' ')),
                ),
              )
              .toList(),
          onChanged: (val) => setState(() => _selectedStatus = val!),
        ),
      ),
    );
  }

  Widget _buildReadOnlyFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoRow("Priority", widget.task.priorityText),
        _infoRow("Department", widget.task.departmentName ?? "-"),
        _infoRow("Creator", widget.task.creatorName ?? "-"),
        _infoRow("Assignee", widget.task.assigneeName ?? "-"),
        _infoRow("Start date", widget.task.createdAt.toString().split(' ')[0]),
        _infoRow("Due date", widget.task.dueDate.toString().split(' ')[0]),
      ],
    );
  }

  Widget _buildEditableFields() {
    return Column(
      children: [
        _buildDropdownRow("Priority", _buildPriorityDropdown()),
        _buildDropdownRow("Due Date", _buildDatePicker()),
        _buildDropdownRow("Department", _buildDeptDropdown()),
        _buildDropdownRow("Assignee", _buildAssigneeDropdown()),
      ],
    );
  }

  Widget _buildDropdownRow(String label, Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              "$label:",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildPriorityDropdown() {
    return _buildStyledContainer(
      DropdownButtonHideUnderline(
        child: DropdownButton<TaskPriority>(
          value: _selectedPriority,
          isExpanded: true,
          isDense: true,
          items: TaskPriority.values
              .map(
                (p) => DropdownMenuItem(
                  value: p,
                  child: Text(p.name, style: const TextStyle(fontSize: 14)),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => _selectedPriority = v),
        ),
      ),
    );
  }

  Widget _buildDatePicker() {
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          firstDate: DateTime.now().subtract(const Duration(days: 365)),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          initialDate: _dueDate ?? DateTime.now(),
        );
        if (d != null) setState(() => _dueDate = d);
      },
      child: _buildStyledContainer(
        Row(
          children: [
            Expanded(
              child: Text(
                _dueDate == null
                    ? "Select date"
                    : "${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}",
                style: const TextStyle(fontSize: 14),
              ),
            ),
            const Icon(Icons.calendar_month, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDeptDropdown() {
    return _buildStyledContainer(
      DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _selectedDeptId,
          isExpanded: true,
          isDense: true,
          hint: const Text("Select Dept", style: TextStyle(fontSize: 14)),
          items: departments
              .map(
                (d) => DropdownMenuItem(
                  value: d.id,
                  child: Text(d.name, style: const TextStyle(fontSize: 14)),
                ),
              )
              .toList(),
          onChanged: (v) => _filterUsersByDept(v),
        ),
      ),
    );
  }

  Widget _buildAssigneeDropdown() {
    return _buildStyledContainer(
      DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _selectedAssigneeId,
          isExpanded: true,
          isDense: true,
          hint: const Text("Select Assignee", style: TextStyle(fontSize: 14)),
          items: filteredUsers
              .map(
                (u) => DropdownMenuItem(
                  value: u.id,
                  child: Text(u.fullName, style: const TextStyle(fontSize: 14)),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => _selectedAssigneeId = v),
        ),
      ),
    );
  }

  Widget _buildStyledContainer(Widget child) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            color: Colors.black,
            fontSize: 13,
            fontFamily: 'Inter',
          ),
          children: [
            TextSpan(
              text: "$label: ",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
