import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/config/app_colors.dart';
import '../../data/models/task_model.dart';
import '../../widgets/task_card.dart';

class StaffJobPage extends StatefulWidget {
  const StaffJobPage({super.key});

  @override
  State<StaffJobPage> createState() => _StaffJobPageState();
}

class _StaffJobPageState extends State<StaffJobPage> {
  String _selectedFilter =
      'All'; // Filter: All, Todo, InProgress, Done, Overdue

  // Mock Data
  final List<TaskModel> _tasks = [
    TaskModel(
      id: '1',
      title: 'Sales Report Q4',
      description: 'Prepare data for the meeting.',
      dueDate: DateTime.now().subtract(const Duration(days: 1)), // Quá hạn
      priority: TaskPriority.high,
      status: TaskStatus.todo,
    ),
    TaskModel(
      id: '2',
      title: 'Design Banner',
      description: 'New marketing campaign.',
      dueDate: DateTime.now().add(const Duration(days: 2)),
      priority: TaskPriority.medium,
      status: TaskStatus.in_progress,
    ),
    TaskModel(
      id: '3',
      title: 'Fix Login Bug',
      description: 'Critical issue on production.',
      dueDate: DateTime.now().add(const Duration(days: 5)),
      priority: TaskPriority.low,
      status: TaskStatus.done,
    ),
  ];

  // Logic lọc
  List<TaskModel> get _filteredTasks {
    if (_selectedFilter == 'All') return _tasks;

    if (_selectedFilter == 'Overdue') {
      final now = DateTime.now();
      return _tasks
          .where((t) => t.dueDate.isBefore(now) && t.status != TaskStatus.done)
          .toList();
    }

    // Map string filter sang Enum status
    return _tasks.where((t) {
      String statusStr = t.status.name
          .replaceAll('_', '')
          .toLowerCase(); // inprogress
      String filterStr = _selectedFilter
          .replaceAll(' ', '')
          .toLowerCase(); // inprogress
      return statusStr == filterStr;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 1. Bộ lọc ngang
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              _buildFilterChip('All'),
              _buildFilterChip('Todo'),
              _buildFilterChip('In Progress'),
              _buildFilterChip('Done'),
              _buildFilterChip('Overdue', isAlert: true),
            ],
          ),
        ),

        // 2. Danh sách
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: _filteredTasks.length,
            itemBuilder: (context, index) {
              return TaskCard(task: _filteredTasks[index], onTap: () {});
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, {bool isAlert = false}) {
    bool isSelected = _selectedFilter == label;
    Color activeColor = isAlert ? Colors.red : AppColors.primary;

    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (val) => setState(() => _selectedFilter = label),
        backgroundColor: Colors.white,
        selectedColor: activeColor,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : const Color(0xFF64748B),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? activeColor : const Color(0xFFE2E8F0),
          ),
        ),
        showCheckmark: false,
      ),
    );
  }
}
