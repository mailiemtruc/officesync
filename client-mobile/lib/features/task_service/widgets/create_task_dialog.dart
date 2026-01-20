// lib/features/task_service/widgets/create_task_dialog.dart

import 'package:flutter/material.dart';
import '../../../../core/api/api_client.dart';
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
  final _titleCtl = TextEditingController();
  final _descCtl = TextEditingController();
  DateTime? dueDate;
  TaskPriority? _selectedPriority;

  List<TaskDepartment> departments = [];
  List<TaskUser> allUsers = [];
  List<TaskUser> filteredUsers = [];

  int? selectedDeptId;
  int? selectedAssigneeId;
  bool loading = false;

  final Color colorBlue = const Color(0xFF2260FF);
  final Color colorNeon = const Color(0xFF55F306);
  final Color colorRed = const Color(0xFFEF4444);

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

  // (Giữ nguyên logic _loadMeta, _onDepartmentChanged và _submit từ code cũ của bạn)
  // ... [Logic nạp dữ liệu giữ nguyên] ...
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
      debugPrint('Lỗi tải metadata: $e');
    }
  }

  void _onDepartmentChanged(int? deptId) {
    setState(() {
      selectedDeptId = deptId;
      selectedAssigneeId = null;

      // Debug để kiểm tra trong Console xem ID soccer có phải là 4 không
      debugPrint("Đang lọc cho phòng ban ID: $deptId");

      filteredUsers = allUsers.where((u) {
        // Chuyển cả 2 về String để so sánh chính xác tuyệt đối
        final bool isInDept = u.departmentId?.toString() == deptId?.toString();
        final bool isNotMe = u.id.toString() != widget.currentUserId.toString();

        if (widget.role == 'COMPANY_ADMIN') {
          // Admin: Tìm người có Role MANAGER
          return isInDept && isNotMe && u.role?.toUpperCase() == 'MANAGER';
        } else if (widget.role == 'MANAGER') {
          // Manager: Tìm người có Role STAFF
          return isInDept && isNotMe && u.role?.toUpperCase() == 'STAFF';
        }
        return isInDept && isNotMe;
      }).toList();

      debugPrint("Tìm thấy ${filteredUsers.length} nhân sự phù hợp.");
    });
  }

  Future<void> _submit() async {
    if (_selectedPriority == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Vui lòng chọn Độ ưu tiên')));
      return;
    }
    setState(() => loading = true);
    try {
      final payload = {
        'title': _titleCtl.text,
        'description': _descCtl.text,
        'departmentId': selectedDeptId,
        'assigneeId': selectedAssigneeId,
        'dueDate': dueDate?.toIso8601String(),
        'priority': _selectedPriority.toString().split('.').last,
        'status': widget.task?.status.toString().split('.').last ?? 'TODO',
      };
      if (widget.task == null)
        await api.post('${ApiClient.taskUrl}/tasks', data: payload);
      else
        await api.put(
          '${ApiClient.taskUrl}/tasks/${widget.task!.id}',
          data: payload,
        );
      Navigator.of(context).pop(true);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Sử dụng Padding với viewInsets.bottom để modal tự đẩy lên khi hiện bàn phím
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        // Bỏ thuộc tính height cố định để modal tự co giãn theo nội dung
        padding: const EdgeInsets.fromLTRB(
          20,
          12,
          20,
          25,
        ), // Padding dưới 25 để thoáng nút bấm
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize
              .min, // QUAN TRỌNG: Modal sẽ thu gọn lại theo nội dung
          children: [
            // Thanh gạch ngang trang trí trên đầu modal
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),

            // Nội dung cuộn (Title, Desc, Settings)
            Flexible(
              // Dùng Flexible thay vì Expanded để không chiếm hết diện tích thừa
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBoxedInput("Title", _titleCtl, isTitle: true),
                    const SizedBox(height: 15),
                    _buildBoxedInput(
                      "Description",
                      _descCtl,
                      minHeight: 120,
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

                    _buildDropdownRow("Priority", _buildDropdownPriority()),
                    _buildDropdownRow("Due Date", _buildDatePicker()),
                    _buildDropdownRow("Department", _buildDeptDropdown()),
                    _buildDropdownRow("Assignee", _buildAssigneeDropdown()),
                  ],
                ),
              ),
            ),

            // KHOẢNG CÁCH 15PX ĐÚNG NHƯ YÊU CẦU
            const SizedBox(height: 15),

            // HÀNG NÚT BẤM (Nằm sát nội dung phía trên 15px)
            Row(
              children: [
                Expanded(
                  child: _actionBtn(
                    widget.task == null ? "Create" : "Save",
                    Icons.check,
                    colorBlue,
                    _submit,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: _actionBtn(
                    "Cancel",
                    Icons.close,
                    colorRed,
                    () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS HỖ TRỢ ---

  Widget _buildBoxedInput(
    String label,
    TextEditingController ctl, {
    bool isTitle = false,
    double minHeight = 0,
    int maxLines = 1,
  }) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: minHeight),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black87),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isTitle ? Colors.grey : Colors.grey,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextField(
            controller: ctl,
            maxLines: maxLines,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.only(top: 4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownRow(String label, Widget dropdown) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.center, // canh giữa theo trục dọc
        children: [
          SizedBox(
            width: 110, // <--- cùng 1 width cho tất cả labels để thẳng hàng
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

  Widget _actionBtn(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return ElevatedButton.icon(
      onPressed: loading ? null : onTap,
      icon: Icon(icon, size: 18, color: Colors.white),
      label: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // -------------------- Priority --------------------
  Widget _buildDropdownPriority() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        // không cần border nếu muốn giống Date (bạn đã bỏ border)
        borderRadius: BorderRadius.circular(15),
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
          icon: const Icon(Icons.arrow_drop_down, size: 20),
        ),
      ),
    );
  }

  // -------------------- Date Picker (giữ như bạn đã chỉnh, chỉ chỉnh text size để đồng bộ) --------------------
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
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(15)),
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

  // -------------------- Department --------------------
  Widget _buildDeptDropdown() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(15)),
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
          icon: const Icon(Icons.arrow_drop_down, size: 20),
        ),
      ),
    );
  }

  // -------------------- Assignee --------------------
  Widget _buildAssigneeDropdown() {
    String hintText = widget.role == 'COMPANY_ADMIN'
        ? "Select Manager"
        : "Select Staff";

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
                  ? "Phòng này chưa có Quản lý"
                  : "Phòng trống",
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
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(15)),
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
          icon: const Icon(Icons.arrow_drop_down, size: 20),
        ),
      ),
    );
  }
}
