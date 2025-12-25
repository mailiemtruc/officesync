import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/config/app_colors.dart';
import '../../data/models/employee_model.dart';
import '../../widgets/employee_card.widget.dart';

import '../../domain/repositories/employee_repository_impl.dart';
import '../../data/datasources/employee_remote_data_source.dart';

class AddMembersPage extends StatefulWidget {
  final List<EmployeeModel> alreadySelectedMembers;
  final String? excludeManagerId; // [MỚI] Nhận ID Manager để loại trừ khỏi list

  const AddMembersPage({
    super.key,
    required this.alreadySelectedMembers,
    this.excludeManagerId,
  });

  @override
  State<AddMembersPage> createState() => _AddMembersPageState();
}

class _AddMembersPageState extends State<AddMembersPage> {
  late final EmployeeRepositoryImpl _repository;
  final _storage = const FlutterSecureStorage();

  List<EmployeeModel> _displayList = []; // Danh sách đang hiển thị từ Search
  Set<String> _selectedIds = {}; // Set chứa ID các member đã chọn

  // [QUAN TRỌNG] Lưu trữ object Member đã chọn để trả về.
  // Vì search list thay đổi liên tục, cần biến này để giữ data những người đã tick.
  Map<String, EmployeeModel> _selectedObjects = {};

  bool _isLoading = false;
  Timer? _debounce;
  String? _currentUserId;
  String _currentFilter = 'All'; // Giữ UI Filter, nhưng logic search là chính

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _repository = EmployeeRepositoryImpl(
      remoteDataSource: EmployeeRemoteDataSource(),
    );

    // Khôi phục trạng thái đã chọn từ trang trước
    for (var emp in widget.alreadySelectedMembers) {
      if (emp.id != null) {
        _selectedIds.add(emp.id!);
        _selectedObjects[emp.id!] = emp;
      }
    }

    _initUserAndFetchDefault();
  }

  Future<void> _initUserAndFetchDefault() async {
    String? userInfoStr = await _storage.read(key: 'user_info');
    if (userInfoStr != null) {
      final userMap = jsonDecode(userInfoStr);
      _currentUserId = userMap['id'].toString();
      _performSearch("");
    }
  }

  Future<void> _performSearch(String keyword) async {
    if (_currentUserId == null) return;
    setState(() => _isLoading = true);
    try {
      final result = await _repository.getEmployeeSuggestions(
        _currentUserId!,
        keyword,
      );
      if (mounted) {
        setState(() {
          // [LOGIC] Lọc bỏ người đang là Manager (Server có thể chưa lọc ID cụ thể này)
          _displayList = result
              .where((e) => e.id != widget.excludeManagerId)
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  // Logic Select All áp dụng cho danh sách đang hiển thị
  void _toggleSelectAll() {
    setState(() {
      final availableIds = _displayList
          .where((e) => e.status != "LOCKED")
          .map((e) => e.id!)
          .toList();

      // Kiểm tra xem tất cả người trong list hiện tại đã được chọn chưa
      bool allVisibleSelected = availableIds.every(
        (id) => _selectedIds.contains(id),
      );

      if (allVisibleSelected) {
        // Bỏ chọn tất cả người đang hiển thị
        _selectedIds.removeAll(availableIds);
        // (Không remove khỏi _selectedObjects để đơn giản, lọc sau khi done)
      } else {
        // Chọn tất cả người đang hiển thị
        _selectedIds.addAll(availableIds);
        for (var emp in _displayList) {
          if (emp.status != "LOCKED") {
            _selectedObjects[emp.id!] = emp;
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Kiểm tra trạng thái Select All cho UI
    final validMembersInView = _displayList
        .where((e) => e.status != "LOCKED")
        .toList();
    final isAllSelected =
        validMembersInView.isNotEmpty &&
        validMembersInView.every((e) => _selectedIds.contains(e.id));

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                const SizedBox(height: 20),
                // Header (Giữ nguyên)
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
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _displayList.isEmpty
                      ? _buildEmptyState(
                          _searchController.text.isNotEmpty
                              ? "No employees found matching '${_searchController.text}'"
                              : "No employees found",
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          itemCount: _displayList.length,
                          itemBuilder: (context, index) {
                            final emp = _displayList[index];
                            final isSelected = _selectedIds.contains(emp.id);
                            final isLocked = emp.status == "LOCKED";

                            return EmployeeCard(
                              employee: emp,
                              isSelected: isSelected,
                              onTap: isLocked
                                  ? null
                                  : () {
                                      setState(() {
                                        if (isSelected) {
                                          _selectedIds.remove(emp.id);
                                          _selectedObjects.remove(emp.id);
                                        } else {
                                          _selectedIds.add(emp.id!);
                                          _selectedObjects[emp.id!] = emp;
                                        }
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
                        // [LOGIC] Lấy danh sách object từ Map dựa trên ID đã chọn
                        final result = _selectedObjects.values.toList();
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
      onChanged: _onSearchChanged, // Gắn Debounce
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

  // [MỚI] Widget hiển thị khi danh sách rỗng (Giống EmployeeListPage)
  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(PhosphorIcons.ghost(), size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(color: Colors.grey[500], fontSize: 16),
          ),
        ],
      ),
    );
  }
}
