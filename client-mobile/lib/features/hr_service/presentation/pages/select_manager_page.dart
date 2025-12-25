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

class SelectManagerPage extends StatefulWidget {
  final String? selectedId;

  const SelectManagerPage({super.key, this.selectedId});

  @override
  State<SelectManagerPage> createState() => _SelectManagerPageState();
}

class _SelectManagerPageState extends State<SelectManagerPage> {
  late final EmployeeRepositoryImpl _repository;
  final _storage = const FlutterSecureStorage();

  List<EmployeeModel> _displayList = [];
  bool _isLoading = false;
  Timer? _debounce;
  String? _currentUserId;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _repository = EmployeeRepositoryImpl(
      remoteDataSource: EmployeeRemoteDataSource(),
    );
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
          _displayList = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error searching: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

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
                          size: 24,
                          color: AppColors.primary,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Center(
                          child: Text(
                            'SELECT MANAGER',
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

                // Search Bar
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

                // Title
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'SUGGESTED STAFF',
                      style: TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                // List Items
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _displayList.isEmpty
                      // [HIỂN THỊ TRẠNG THÁI RỖNG ĐẸP]
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
                            // [SỬA LỖI LOGIC]
                            // So sánh ID với ID đã chọn ban đầu (Single Select)
                            final isSelected =
                                emp.id.toString() == widget.selectedId;
                            final isLocked = emp.status == "LOCKED";

                            return EmployeeCard(
                              employee: emp,
                              isSelected: isSelected,
                              // [SỬA LỖI ONTAP]
                              // Chọn xong thì trả về luôn (Navigator.pop)
                              onTap: isLocked
                                  ? null
                                  : () => Navigator.pop(context, emp),
                              selectionWidget: _buildSelectionIcon(
                                isSelected,
                                isLocked,
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
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Search name, employee ID...',
          hintStyle: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 14),
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

  Widget _buildSelectionIcon(bool isSelected, bool isLocked) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected ? AppColors.primary : Colors.white,
        border: Border.all(
          color: isSelected ? AppColors.primary : const Color(0xFF9CA3AF),
          width: 1.5,
        ),
      ),
      child: isSelected && !isLocked
          ? const Icon(Icons.check, size: 16, color: Colors.white)
          : null,
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
