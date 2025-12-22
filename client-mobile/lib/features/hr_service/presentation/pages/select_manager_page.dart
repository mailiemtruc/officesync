import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/config/app_colors.dart';
import '../../data/models/employee_model.dart';
import '../../widgets/employee_card.widget.dart';
import '../../widgets/employee_bottom_sheet.dart';

class SelectManagerPage extends StatefulWidget {
  final String? selectedId;
  final List<EmployeeModel> availableEmployees; // Nhận danh sách từ bên ngoài

  const SelectManagerPage({
    super.key,
    this.selectedId,
    required this.availableEmployees,
  });

  @override
  State<SelectManagerPage> createState() => _SelectManagerPageState();
}

class _SelectManagerPageState extends State<SelectManagerPage> {
  // Biến để search
  late List<EmployeeModel> _displayList;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _displayList = widget.availableEmployees;
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _displayList = widget.availableEmployees.where((emp) {
        final name = emp.fullName.toLowerCase();
        final id = (emp.id ?? "").toLowerCase();
        return name.contains(query) || id.contains(query);
      }).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // void _showEmployeeOptions(EmployeeModel emp) {
  //   // Logic hiển thị bottom sheet (giữ nguyên UI, chỉ đổi Model)
  //   showModalBottomSheet(
  //     context: context,
  //     isScrollControlled: true,
  //     backgroundColor: Colors.transparent,
  //     builder: (context) => EmployeeBottomSheet(
  //       employee: emp,
  //       onToggleLock:
  //           () {}, // Tạm thời disable logic lock ở đây nếu không cần thiết
  //       onDelete: () {},
  //     ),
  //   );
  // }

  @override
  Widget build(BuildContext context) {
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
                        icon: const Icon(
                          Icons.arrow_back_ios,
                          size: 20,
                          color: Colors.blue,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Center(
                          child: Text(
                            'SELECT MANAGER',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 20,
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

                const SizedBox(height: 12),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'AVAILABLE STAFF', // Đổi title cho hợp ngữ cảnh
                      style: TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                // List
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: _displayList.length,
                    itemBuilder: (context, index) {
                      final emp = _displayList[index];
                      final isSelected = emp.id == widget.selectedId;
                      final isLocked = emp.status == "LOCKED";

                      return EmployeeCard(
                        employee:
                            emp, // Sử dụng widget EmployeeCard mới đã update
                        isSelected: isSelected,
                        onTap: isLocked
                            ? null
                            : () => Navigator.pop(context, emp),
                        // onMenuTap: () => _showEmployeeOptions(emp),
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 45,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
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
  }

  Widget _buildFilterButton() {
    return Container(
      width: 45,
      height: 45,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
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
  }
}
