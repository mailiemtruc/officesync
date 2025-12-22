import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/config/app_colors.dart';
import '../../data/models/employee_model.dart';
import '../../widgets/employee_card.widget.dart';
import '../../widgets/employee_bottom_sheet.dart';

class AddMembersPage extends StatefulWidget {
  final List<EmployeeModel> alreadySelectedMembers;
  final List<EmployeeModel> availableEmployees; // Nhận danh sách đã lọc

  const AddMembersPage({
    super.key,
    required this.alreadySelectedMembers,
    required this.availableEmployees,
  });

  @override
  State<AddMembersPage> createState() => _AddMembersPageState();
}

class _AddMembersPageState extends State<AddMembersPage> {
  late Set<String> _selectedIds;
  late List<EmployeeModel> _displayList;
  String _currentFilter = 'All';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedIds = widget.alreadySelectedMembers.map((e) => e.id!).toSet();
    _displayList = widget.availableEmployees;
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    setState(() {}); // Rebuild để filter lại trong getter _filteredEmployees
  }

  // Logic lọc hiển thị
  List<EmployeeModel> get _filteredEmployees {
    List<EmployeeModel> list = widget.availableEmployees;

    // 1. Filter theo Tab
    if (_currentFilter == 'Unassigned') {
      list = list
          .where((e) => e.role == "Unassigned" || e.departmentName == null)
          .toList();
    }

    // 2. Filter theo Search
    final query = _searchController.text.toLowerCase();
    if (query.isNotEmpty) {
      list = list.where((e) {
        final name = e.fullName.toLowerCase();
        return name.contains(query);
      }).toList();
    }

    return list;
  }

  void _toggleSelectAll() {
    setState(() {
      final availableIds = _filteredEmployees
          .where((e) => e.status != "LOCKED")
          .map((e) => e.id!)
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
    final currentList = _filteredEmployees;
    final validMembers = currentList
        .where((e) => e.status != "LOCKED")
        .toList();

    final isAllSelected =
        validMembers.isNotEmpty &&
        _selectedIds.containsAll(validMembers.map((e) => e.id));

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
                // Search & Filter
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
                        'AVAILABLE STAFF',
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
                    itemCount: currentList.length,
                    itemBuilder: (context, index) {
                      final emp = currentList[index];
                      final isSelected = _selectedIds.contains(emp.id);
                      final isLocked = emp.status == "LOCKED";

                      return EmployeeCard(
                        employee: emp,
                        isSelected: isSelected,
                        onTap: isLocked
                            ? null
                            : () {
                                setState(() {
                                  if (isSelected)
                                    _selectedIds.remove(emp.id);
                                  else
                                    _selectedIds.add(emp.id!);
                                });
                              },
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
                          child: isSelected && !isLocked
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
                        // Trả về danh sách full object
                        final result = widget.availableEmployees
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

  Widget _buildSearchBar() => Container(
    height: 45,
    decoration: BoxDecoration(
      color: const Color(0xFFF5F5F5),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE0E0E0)),
    ),
    child: TextField(
      controller: _searchController,
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

  Widget _buildFilterButton() {
    // Giữ nguyên UI cũ
    return Container(
      width: 45,
      height: 45,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: const Icon(Icons.filter_list, color: Color(0xFF555252)),
    );
  }

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
