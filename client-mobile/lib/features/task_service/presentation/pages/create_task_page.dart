import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';
import '../../../../core/config/app_colors.dart';
import '../../../../core/widgets/custom_text_field.dart';
import '../../data/models/task_model.dart';
// Lưu ý: Sửa lại đường dẫn import này cho đúng với máy bạn
import '../../../hr_service/presentation/pages/add_members_page.dart';
import '../../../hr_service/data/models/employee_model.dart';

class CreateTaskPage extends StatefulWidget {
  final String currentUserRole; // Nhận role từ TaskListPage truyền sang

  const CreateTaskPage({super.key, required this.currentUserRole});

  @override
  State<CreateTaskPage> createState() => _CreateTaskPageState();
}

class _CreateTaskPageState extends State<CreateTaskPage> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _dueDateController = TextEditingController();

  TaskPriority _selectedPriority = TaskPriority.medium;
  EmployeeModel? _assignee;

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _dueDateController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  Future<void> _pickAssignee() async {
    // Logic chọn người nhận việc
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        // Giả sử AddMembersPage có logic load nhân viên
        builder: (context) => const AddMembersPage(alreadySelectedMembers: []),
      ),
    );

    if (result != null && result is List<EmployeeModel> && result.isNotEmpty) {
      setState(() {
        _assignee = result.first;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Text hướng dẫn thay đổi theo Role
    String instructionText = "";
    String placeholderText = "Select Employee";

    if (widget.currentUserRole == 'COMPANY_ADMIN') {
      instructionText = "Assigning to a Manager";
      placeholderText = "Select Manager";
    } else if (widget.currentUserRole == 'MANAGER') {
      instructionText = "Assigning to a Staff Member";
      placeholderText = "Select Staff";
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  _buildHeader(),
                  const SizedBox(height: 32),

                  _buildLabel('Task Title'),
                  CustomTextField(
                    controller: _titleController,
                    hintText: 'Enter task title',
                  ),
                  const SizedBox(height: 20),

                  _buildLabel('Description'),
                  CustomTextField(
                    controller: _descController,
                    hintText: 'Detailed instructions...',
                    maxLines: 4,
                  ),
                  const SizedBox(height: 20),

                  _buildLabel('Due Date'),
                  GestureDetector(
                    onTap: _selectDate,
                    child: AbsorbPointer(
                      child: CustomTextField(
                        controller: _dueDateController,
                        hintText: 'Select Date',
                        suffixIcon: Icon(
                          PhosphorIcons.calendarBlank(),
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  _buildLabel('Priority'),
                  _buildPrioritySelector(),
                  const SizedBox(height: 20),

                  // Phần chọn người nhận việc
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildLabel('Assign To'),
                      Text(
                        instructionText,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                  _buildAssigneeSelector(placeholderText),

                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: const Text(
                        'Create Task',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ... (Giữ nguyên các widget con: _buildHeader, _buildLabel, _buildPrioritySelector)
  Widget _buildHeader() {
    return Row(
      children: [
        IconButton(
          icon: Icon(
            PhosphorIcons.caretLeft(PhosphorIconsStyle.bold),
            color: AppColors.primary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        const Expanded(
          child: Center(
            child: Text(
              'NEW TASK',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 40),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Color(0xFF64748B),
        ),
      ),
    );
  }

  Widget _buildPrioritySelector() {
    return Row(
      children: TaskPriority.values.map((priority) {
        bool isSelected = _selectedPriority == priority;
        Color color;
        if (priority == TaskPriority.high)
          color = Colors.red;
        else if (priority == TaskPriority.medium)
          color = Colors.orange;
        else
          color = Colors.green;

        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedPriority = priority),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? color.withValues(alpha: 0.1) : Colors.white,
                border: Border.all(
                  color: isSelected ? color : const Color(0xFFE2E8F0),
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                priority.name.toUpperCase(),
                style: TextStyle(
                  color: isSelected ? color : const Color(0xFF94A3B8),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAssigneeSelector(String placeholder) {
    return InkWell(
      onTap: _pickAssignee,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFECF1FF)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Color(0xFFEFF6FF),
                shape: BoxShape.circle,
              ),
              child: _assignee?.avatarUrl != null
                  ? ClipOval(
                      child: Image.network(
                        _assignee!.avatarUrl!,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Icon(PhosphorIcons.user(), color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _assignee?.fullName ?? placeholder,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: _assignee != null
                      ? FontWeight.w600
                      : FontWeight.normal,
                  color: _assignee != null
                      ? Colors.black
                      : const Color(0xFF9CA3AF),
                ),
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Color(0xFFBDC6DE),
            ),
          ],
        ),
      ),
    );
  }
}
