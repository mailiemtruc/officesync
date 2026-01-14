// lib/features/task_service/widgets/task_detail_dialog.dart
import 'package:flutter/material.dart';
import '../../../../core/api/api_client.dart';
import '../data/models/task_model.dart';

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
  late TaskStatus _selectedStatus;
  bool _isUpdating = false;

  final Color colorBlue = const Color(0xFF2260FF);
  final Color colorNeon = const Color(0xFF55F306);
  final Color colorRed = const Color(0xFFEF4444);

  // LOGIC PHÂN QUYỀN XÓA:
  bool get _canDelete {
    // 1. Nếu là Admin Company -> Luôn hiển thị thùng rác để có quyền quản lý cao nhất
    if (widget.role == 'COMPANY_ADMIN') return true;

    // 2. Với Manager/Staff -> So sánh ID (ép kiểu String để tránh lỗi int vs String từ API)
    return widget.currentUserId.toString() == widget.task.creatorId.toString();
  }

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.task.status;
  }

  // HÀM XỬ LÝ XÓA TASK
  Future<void> _handleDelete() async {
    bool confirm =
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Xác nhận xóa"),
            content: const Text(
              "Bạn có chắc chắn muốn xóa task này? Hành động này không thể hoàn tác.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Hủy"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text("Xóa", style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    try {
      await api.delete('${ApiClient.taskUrl}/tasks/${widget.task.id}');
      widget.onRefresh();
      Navigator.pop(context); // Đóng modal chi tiết
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Đã xóa task thành công")));
    } catch (e) {
      debugPrint("Delete error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    double sheetHeight = MediaQuery.of(context).size.height * 0.65;

    // Log debug kiểm tra ID thực tế
    debugPrint(
      "DEBUG: UserID(${widget.currentUserId}) | CreatorID(${widget.task.creatorId}) | ShowTrash: $_canDelete",
    );

    return Container(
      height: sheetHeight,
      // Padding top nhỏ để icon thùng rác có thể nằm sát mép trên
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none, // Cho phép icon nổi lên trên vùng padding
        children: [
          Column(
            children: [
              // KHOẢNG TRỐNG ĐỂ TIÊU ĐỀ KHÔNG BỊ TRÙNG VỚI ICON THÙNG RÁC
              const SizedBox(height: 50),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBoxedField(
                        "Title",
                        widget.task.title,
                        isTitle: true,
                      ),
                      const SizedBox(height: 15),
                      _buildBoxedField(
                        "Description",
                        widget.task.description,
                        minHeight: 100,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "Update status:",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      DropdownButton<TaskStatus>(
                        value: _selectedStatus,
                        isExpanded: true,
                        items:
                            [
                                  TaskStatus.TODO,
                                  TaskStatus.IN_PROGRESS,
                                  TaskStatus.DONE,
                                ]
                                .map(
                                  (s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(s.name.replaceAll('_', ' ')),
                                  ),
                                )
                                .toList(),
                        onChanged: (val) =>
                            setState(() => _selectedStatus = val!),
                      ),
                      const Divider(),
                      _infoRow("Priority", widget.task.priorityText),
                      _infoRow("Department", widget.task.departmentName ?? "-"),
                      _infoRow("Creator", widget.task.creatorName ?? "-"),
                      _infoRow("Assignee", widget.task.assigneeName ?? "-"),
                      _infoRow(
                        "Start date",
                        widget.task.createdAt.toString().split(' ')[0],
                      ),
                      _infoRow(
                        "Due date",
                        widget.task.dueDate.toString().split(' ')[0],
                      ),
                      _infoRow(
                        "Visibility",
                        widget.task.isPublished ? "Public" : "Draft",
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _actionBtn(
                      "Save",
                      Icons.check,
                      colorBlue,
                      _updateTaskInfo,
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

          // NÚT XÓA (ICON THÙNG RÁC): Đặt sát góc trên bên phải
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
    );
  }

  Widget _buildBoxedField(
    String label,
    String value, {
    bool isTitle = false,
    double minHeight = 0,
  }) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: minHeight),
      padding: const EdgeInsets.all(12),
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
              color: isTitle ? colorNeon : Colors.grey,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black, fontSize: 13),
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

  Widget _actionBtn(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return ElevatedButton.icon(
      onPressed: _isUpdating ? null : onTap,
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

  Future<void> _updateTaskInfo() async {
    setState(() => _isUpdating = true);
    try {
      final payload = widget.task.toJson();
      payload['status'] = _selectedStatus.toString().split('.').last;
      await api.put(
        '${ApiClient.taskUrl}/tasks/${widget.task.id}',
        data: payload,
      );
      widget.onRefresh();
      Navigator.pop(context);
    } catch (e) {
      debugPrint("Update error: $e");
    } finally {
      setState(() => _isUpdating = false);
    }
  }
}
