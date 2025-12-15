import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/config/app_colors.dart';
import '../../data/models/employee_model.dart';
import '../../widgets/employee_card.widget.dart';
import '../../widgets/employee_bottom_sheet.dart';

class AddMembersPage extends StatefulWidget {
  final List<Employee> alreadySelectedMembers;
  const AddMembersPage({super.key, required this.alreadySelectedMembers});

  @override
  State<AddMembersPage> createState() => _AddMembersPageState();
}

class _AddMembersPageState extends State<AddMembersPage> {
  final List<Employee> _allEmployees = [
    Employee(
      id: "012",
      name: "Nguyen Van Cuong",
      role: "Unassigned",
      department: "",
      imageUrl: "https://i.pravatar.cc/150?img=12",
    ),
    Employee(
      id: "067",
      name: "Tran Thi Trang",
      role: "Unassigned",
      department: "",
      imageUrl: "https://i.pravatar.cc/150?img=5",
    ),
    Employee(
      id: "017",
      name: "Nguyen Van J",
      role: "Staff",
      department: "Technical",
      imageUrl: "https://i.pravatar.cc/150?img=15",
      isLocked: true,
    ), // User bị khóa
    Employee(
      id: "061",
      name: "Nguyen Van K",
      role: "Staff",
      department: "Human resource",
      imageUrl: "https://i.pravatar.cc/150?img=60",
    ),
  ];

  late Set<String> _selectedIds;
  String _currentFilter = 'All';

  @override
  void initState() {
    super.initState();
    _selectedIds = widget.alreadySelectedMembers.map((e) => e.id).toSet();
  }

  void _showEmployeeOptions(Employee emp) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EmployeeBottomSheet(
        employee: emp,
        onToggleLock: () => setState(() {
          emp.isLocked = !emp.isLocked;
          // Nếu khóa -> tự động bỏ chọn
          if (emp.isLocked) _selectedIds.remove(emp.id);
        }),
        onDelete: () => setState(() {
          _allEmployees.removeWhere((e) => e.id == emp.id);
          _selectedIds.remove(emp.id);
        }),
      ),
    );
  }

  List<Employee> get _filteredEmployees {
    if (_currentFilter == 'Unassigned')
      return _allEmployees.where((e) => e.role == "Unassigned").toList();
    return _allEmployees;
  }

  void _toggleSelectAll() {
    setState(() {
      // Chỉ chọn những người KHÔNG BỊ KHÓA
      final availableIds = _filteredEmployees
          .where((e) => !e.isLocked)
          .map((e) => e.id)
          .toList();

      if (_selectedIds.containsAll(availableIds)) {
        _selectedIds.removeAll(availableIds);
      } else {
        _selectedIds.addAll(availableIds);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final availableEmployees = _filteredEmployees
        .where((e) => !e.isLocked)
        .toList();
    final isAllSelected =
        availableEmployees.isNotEmpty &&
        _selectedIds.containsAll(availableEmployees.map((e) => e.id));

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                const SizedBox(height: 20),
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          PhosphorIcons.caretLeft(PhosphorIconsStyle.bold),
                          color: AppColors.primary,
                          size: 24,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Center(
                          child: Text(
                            'ADD MEMBERS',
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
                  ),
                ),
                const SizedBox(height: 24),
                // Search & Filter (Đồng bộ)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Expanded(child: _buildSearchBar()),
                      const SizedBox(width: 12),
                      _buildFilterButton(),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Tabs
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      _buildTabButton('All'),
                      const SizedBox(width: 12),
                      _buildTabButton('Unassigned'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Select All
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'AVAILABLE EMPLOYEES',
                        style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      GestureDetector(
                        onTap: _toggleSelectAll,
                        child: Text(
                          isAllSelected ? 'UNSELECT ALL' : 'SELECT ALL',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // List Items
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: _filteredEmployees.length,
                    itemBuilder: (context, index) {
                      final emp = _filteredEmployees[index];
                      final isSelected = _selectedIds.contains(emp.id);

                      return EmployeeCard(
                        name: emp.name,
                        employeeId: emp.id,
                        role: emp.role,
                        department: emp.department,
                        imageUrl: emp.imageUrl,
                        isLocked: emp.isLocked,
                        isSelected: isSelected,

                        // Nếu bị khóa -> onTap là null
                        onTap: emp.isLocked
                            ? null
                            : () {
                                setState(() {
                                  if (isSelected)
                                    _selectedIds.remove(emp.id);
                                  else
                                    _selectedIds.add(emp.id);
                                });
                              },

                        onMenuTap: () => _showEmployeeOptions(emp),

                        // Widget chọn: Checkbox
                        selectionWidget: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? AppColors.primary
                                : Colors.white,
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : const Color(0xFF9CA3AF),
                              width: 1.5,
                            ),
                          ),
                          child: isSelected && !emp.isLocked
                              ? const Icon(
                                  Icons.check,
                                  size: 16,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      );
                    },
                  ),
                ),

                // Bottom Button
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        final result = _allEmployees
                            .where((e) => _selectedIds.contains(e.id))
                            .toList();
                        Navigator.pop(context, result);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        elevation: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Add Members',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (_selectedIds.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${_selectedIds.length}',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
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

  // (Widget search & filter giống trang select manager)
  Widget _buildSearchBar() => Container(
    height: 45,
    decoration: BoxDecoration(
      color: const Color(0xFFF5F5F5),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE0E0E0)),
    ),
    child: TextField(
      decoration: InputDecoration(
        hintText: 'Search name, employee ID...',
        hintStyle: const TextStyle(
          color: Color(0xFF9E9E9E),
          fontSize: 14,
          fontWeight: FontWeight.w300,
        ),
        prefixIcon: Icon(
          PhosphorIcons.magnifyingGlass(),
          color: const Color(0xFF757575),
          size: 20,
        ),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
      ),
    ),
  );
  Widget _buildFilterButton() => Container(
    width: 45,
    height: 45,
    decoration: BoxDecoration(
      color: const Color(0xFFF5F5F5),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE0E0E0)),
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {},
        child: Icon(
          PhosphorIcons.funnel(PhosphorIconsStyle.regular),
          color: const Color(0xFF555252),
          size: 20,
        ),
      ),
    ),
  );
  Widget _buildTabButton(String label) {
    bool isSelected = _currentFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _currentFilter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF4B5563),
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
