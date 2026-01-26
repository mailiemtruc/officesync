// lib/features/task_service/widgets/create_task_dialog.dart

import 'package:flutter/material.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/config/app_colors.dart';
import '../../../../core/utils/custom_snackbar.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../../core/widgets/custom_text_field.dart';

import '../data/models/task_user.dart';
import '../data/models/task_department.dart';
import '../data/models/task_model.dart';

class CreateTaskDialog extends StatefulWidget {
  final String role;
  final int currentUserId;
  final TaskModel? task;

  const CreateTaskDialog({
    super.key,
    required this.role,
    required this.currentUserId,
    this.task,
  });

  @override
  State<CreateTaskDialog> createState() => _CreateTaskDialogState();
}

class _CreateTaskDialogState extends State<CreateTaskDialog> {
  final ApiClient api = ApiClient();

  // Controllers
  final _titleCtl = TextEditingController();
  final _descCtl = TextEditingController();

  // State Data
  DateTime? dueDate;
  TaskPriority? _selectedPriority;
  int? selectedDeptId;
  int? selectedAssigneeId;

  // Lists
  List<TaskDepartment> departments = [];
  List<TaskUser> allUsers = [];
  List<TaskUser> filteredUsers = [];

  // UI State
  bool loading = false;
  String? _errorMessage;

  // Colors
  final Color colorRed = const Color(0xFFEF4444);
  final Color colorBlue = const Color(0xFF2260FF);

  @override
  void initState() {
    super.initState();
    if (widget.task != null) {
      _titleCtl.text = widget.task!.title;
      _descCtl.text = widget.task!.description;
      dueDate = widget.task!.dueDate;
      selectedDeptId = widget.task!.departmentId;
      selectedAssigneeId = widget.task!.assigneeId;
      _selectedPriority = widget.task!.priority;
    }
    _loadMeta();
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
            final managedDeptIds = departments.map((d) => d.id).toSet();
            allUsers = (usersResp.data as List)
                .map((e) => TaskUser.fromJson(Map<String, dynamic>.from(e)))
                .where(
                  (u) =>
                      managedDeptIds.contains(u.departmentId) &&
                      u.id != widget.currentUserId,
                )
                .toList();
          } else {
            departments = allDepts;
            allUsers = (usersResp.data as List)
                .map((e) => TaskUser.fromJson(Map<String, dynamic>.from(e)))
                .toList();
          }

          if (departments.isNotEmpty) {
            selectedDeptId = (widget.task == null)
                ? departments.first.id
                : (departments.any((d) => d.id == widget.task!.departmentId)
                      ? widget.task!.departmentId
                      : departments.first.id);
            _onDepartmentChanged(selectedDeptId);
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading metadata: $e');
    }
  }

  void _onDepartmentChanged(int? deptId) {
    setState(() {
      selectedDeptId = deptId;
      selectedAssigneeId = null;
      filteredUsers = allUsers.where((u) {
        final bool isInDept = u.departmentId?.toString() == deptId?.toString();
        final bool isNotMe = u.id.toString() != widget.currentUserId.toString();
        if (widget.role == 'COMPANY_ADMIN') {
          return isInDept && isNotMe && u.role?.toUpperCase() == 'MANAGER';
        } else if (widget.role == 'MANAGER') {
          return isInDept && isNotMe && u.role?.toUpperCase() == 'STAFF';
        }
        return isInDept && isNotMe;
      }).toList();
    });
  }

  // --- [SỬA] LOGIC VALIDATION & SUBMIT (TIẾNG ANH) ---
  Future<void> _submit() async {
    // Reset error
    setState(() => _errorMessage = null);

    // Validation messages in English
    if (_titleCtl.text.trim().isEmpty) {
      setState(() => _errorMessage = "Please enter the task title");
      return;
    }
    if (_descCtl.text.trim().isEmpty) {
      setState(() => _errorMessage = "Please enter the description");
      return;
    }
    if (_selectedPriority == null) {
      setState(() => _errorMessage = "Please select a priority level");
      return;
    }
    if (dueDate == null) {
      setState(() => _errorMessage = "Please select a due date");
      return;
    }
    if (selectedDeptId == null) {
      setState(() => _errorMessage = "Please select a department");
      return;
    }
    if (selectedAssigneeId == null) {
      setState(() => _errorMessage = "Please select an assignee");
      return;
    }

    // Call API
    setState(() => loading = true);
    try {
      final payload = {
        'title': _titleCtl.text.trim(),
        'description': _descCtl.text.trim(),
        'departmentId': selectedDeptId,
        'assigneeId': selectedAssigneeId,
        'dueDate': dueDate?.toIso8601String(),
        'priority': _selectedPriority.toString().split('.').last,
        'status': widget.task?.status.toString().split('.').last ?? 'TODO',
      };

      if (widget.task == null) {
        await api.post('${ApiClient.taskUrl}/tasks', data: payload);
        if (mounted) {
          CustomSnackBar.show(
            context,
            title: 'Success',
            message: 'Task created successfully.',
            isError: false,
          );
        }
      } else {
        await api.put(
          '${ApiClient.taskUrl}/tasks/${widget.task!.id}',
          data: payload,
        );
        if (mounted) {
          CustomSnackBar.show(
            context,
            title: 'Updated',
            message: 'Task information saved successfully.',
            isError: false,
          );
        }
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 25),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Decorative Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),

            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel("Title *"),
                    CustomTextField(
                      controller: _titleCtl,
                      hintText: "Enter task title",
                    ),
                    const SizedBox(height: 15),

                    _buildLabel("Description *"),
                    CustomTextField(
                      controller: _descCtl,
                      hintText: "Enter description",
                      maxLines: 5,
                    ),

                    const SizedBox(height: 20),
                    const Text(
                      "Task Settings:",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const Divider(),

                    _buildDropdownRow("Priority *", _buildDropdownPriority()),
                    _buildDropdownRow("Due Date *", _buildDatePicker()),
                    _buildDropdownRow("Department *", _buildDeptDropdown()),
                    _buildDropdownRow("Assignee *", _buildAssigneeDropdown()),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 15),

            // --- ERROR MESSAGE BOX ON MODAL ---
            if (_errorMessage != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 15),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colorRed.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: colorRed, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: colorRed,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    text: widget.task == null ? "Create" : "Save",
                    onPressed: loading ? () {} : _submit,
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
      ),
    );
  }

  // --- Helper Widgets ---
  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
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

  Widget _buildDropdownRow(String label, Widget dropdown) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              "$label:",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          Expanded(child: dropdown),
        ],
      ),
    );
  }

  Widget _buildDropdownPriority() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(13),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<TaskPriority>(
          value: _selectedPriority,
          isExpanded: true,
          hint: const Text("Select", style: TextStyle(fontSize: 14)),
          items: TaskPriority.values
              .map(
                (p) => DropdownMenuItem(
                  value: p,
                  child: Text(p.name, style: const TextStyle(fontSize: 14)),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => _selectedPriority = v),
          icon: const Icon(Icons.arrow_drop_down, size: 24),
        ),
      ),
    );
  }

  Widget _buildDatePicker() {
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          initialDate: dueDate ?? DateTime.now(),
          builder: (context, child) {
            return Theme(
              data: Theme.of(
                context,
              ).copyWith(colorScheme: ColorScheme.light(primary: colorBlue)),
              child: child!,
            );
          },
        );
        if (d != null) setState(() => dueDate = d);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.inputFill,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                dueDate == null
                    ? "Choose a date"
                    : "${dueDate!.day}/${dueDate!.month}/${dueDate!.year}",
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(13),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: selectedDeptId,
          isExpanded: true,
          hint: const Text(
            "Choose a department",
            style: TextStyle(fontSize: 14),
          ),
          items: departments
              .map(
                (d) => DropdownMenuItem(
                  value: d.id,
                  child: Text(d.name, style: const TextStyle(fontSize: 14)),
                ),
              )
              .toList(),
          onChanged: (v) => _onDepartmentChanged(v),
          icon: const Icon(Icons.arrow_drop_down, size: 24),
        ),
      ),
    );
  }

  Widget _buildAssigneeDropdown() {
    String hintText = widget.role == 'COMPANY_ADMIN'
        ? "Select Manager"
        : "Select Staff";

    // [SỬA] Thông báo danh sách trống bằng Tiếng Anh
    if (selectedDeptId != null && filteredUsers.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              widget.role == 'COMPANY_ADMIN'
                  ? "No Manager in this Dept"
                  : "No Staff in this Dept",
              style: const TextStyle(
                color: Colors.orange,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(13),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: selectedAssigneeId,
          isExpanded: true,
          hint: Text(hintText, style: const TextStyle(fontSize: 14)),
          items: filteredUsers.map((u) {
            return DropdownMenuItem<int>(
              value: u.id,
              child: Text(
                u.fullName,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }).toList(),
          onChanged: (v) => setState(() => selectedAssigneeId = v),
          icon: const Icon(Icons.arrow_drop_down, size: 24),
        ),
      ),
    );
  }
}
