import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/services/websocket_service.dart';
import 'package:intl/intl.dart';
import '../../../../core/config/app_colors.dart';
import '../../data/models/request_model.dart';
import '../../data/datasources/request_remote_data_source.dart';
import '../../domain/repositories/request_repository_impl.dart';
import '../../domain/repositories/request_repository.dart';
import 'dart:async';
import 'create_request_page.dart';
import 'request_detail_page.dart';

enum FilterType { none, date, month, year }

class MyRequestsPage extends StatefulWidget {
  const MyRequestsPage({super.key});

  @override
  State<MyRequestsPage> createState() => _MyRequestsPageState();
}

class _MyRequestsPageState extends State<MyRequestsPage> {
  String _selectedFilter = 'All'; // Tab lọc Client-side (Pending, Approved...)
  List<RequestModel> _requests = [];
  bool _isLoading = true;

  final _storage = const FlutterSecureStorage();
  late final RequestRepository _repository;

  // Biến Socket
  bool _isSocketInitialized = false;
  dynamic _unsubscribeFn;

  // Biến Tìm kiếm & Lọc Server-side
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  // [CẬP NHẬT] Thay thế _selectedMonth bằng bộ biến mới này
  DateTime? _selectedDate;
  FilterType _filterType = FilterType.none;

  @override
  void initState() {
    super.initState();
    _repository = RequestRepositoryImpl(
      remoteDataSource: RequestRemoteDataSource(),
    );
    _fetchRequests();
  }

  @override
  void dispose() {
    if (_unsubscribeFn != null) {
      _unsubscribeFn(unsubscribeHeaders: const <String, String>{});
    }
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<String?> _getUserIdFromStorage() async {
    try {
      String? userInfoStr = await _storage.read(key: 'user_info');
      if (userInfoStr != null) {
        Map<String, dynamic> userMap = jsonDecode(userInfoStr);
        return userMap['id']?.toString();
      }
      return await _storage.read(key: 'userId');
    } catch (e) {
      return null;
    }
  }

  void _initListener(String userId) {
    final topic = '/topic/user/$userId/requests';

    _unsubscribeFn = WebSocketService().subscribe(topic, (data) {
      if (!mounted) return;

      if (data is Map<String, dynamic>) {
        final updatedReq = RequestModel.fromJson(data);
        setState(() {
          // Cập nhật hoặc thêm mới vào danh sách
          final index = _requests.indexWhere((r) => r.id == updatedReq.id);
          if (index != -1) {
            _requests[index] = updatedReq;
          } else {
            _requests.insert(0, updatedReq);
          }
        });
      }
      // Nếu là sự kiện xóa (data chỉ có id)
      else if (data is String && data == "DELETE") {
        _fetchRequests(); // Reload lại cho chắc
      }
    });
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      if (mounted) {
        _fetchRequests();
      }
    });
  }

  // [CẬP NHẬT] Hàm gọi API với logic lọc Ngày/Tháng/Năm
  Future<void> _fetchRequests() async {
    if (!mounted) return;

    setState(() => _isLoading = true);
    try {
      final userId = await _getUserIdFromStorage();
      if (userId != null) {
        if (!_isSocketInitialized) {
          _initListener(userId);
          _isSocketInitialized = true;
        }

        // [LOGIC MỚI] Tính toán tham số day/month/year
        int? d, m, y;
        if (_selectedDate != null) {
          if (_filterType == FilterType.date) {
            d = _selectedDate!.day;
            m = _selectedDate!.month;
            y = _selectedDate!.year;
          } else if (_filterType == FilterType.month) {
            m = _selectedDate!.month;
            y = _selectedDate!.year;
          } else if (_filterType == FilterType.year) {
            y = _selectedDate!.year;
          }
        }

        // Gọi API
        final data = await _repository.getMyRequests(
          userId,
          search: _searchController.text,
          // Lưu ý: Đảm bảo RequestRepository đã update để nhận tham số 'day'
          // Nếu chưa, bạn cần thêm tham số 'day' vào Repository và DataSource như đã làm với Manager
          day: d,
          month: m,
          year: y,
        );

        if (mounted) {
          setState(() {
            _requests = data;
          });
        }
      } else {
        print("User ID not found!");
      }
    } catch (e) {
      print("Error fetching requests: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- CÁC HÀM XỬ LÝ UI LỌC (GIỐNG MANAGER PAGE) ---

  // 1. Menu chọn loại lọc (Bottom Sheet Mượt mà)
  void _onFilterTap() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  // Handle bar
                  Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title & Reset
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Filter My Requests",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Inter',
                            color: Color(0xFF111827),
                          ),
                        ),
                        if (_filterType != FilterType.none)
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              Future.delayed(
                                const Duration(milliseconds: 200),
                                () {
                                  _clearFilter();
                                },
                              );
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFDC2626),
                            ),
                            child: const Text(
                              "Reset",
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Options
                  _buildEnhancedFilterOption(
                    icon: PhosphorIcons.calendar(),
                    text: "Specific Date",
                    subText: "Filter by a specific day",
                    isSelected: _filterType == FilterType.date,
                    onTap: () async {
                      setModalState(() => _filterType = FilterType.date);
                      await Future.delayed(const Duration(milliseconds: 150));
                      if (context.mounted) Navigator.pop(context);
                      await Future.delayed(const Duration(milliseconds: 300));
                      _pickDate();
                    },
                  ),
                  const SizedBox(height: 12),

                  _buildEnhancedFilterOption(
                    icon: PhosphorIcons.calendarBlank(),
                    text: "Month & Year",
                    subText: "Filter by month",
                    isSelected: _filterType == FilterType.month,
                    onTap: () async {
                      setModalState(() => _filterType = FilterType.month);
                      await Future.delayed(const Duration(milliseconds: 150));
                      if (context.mounted) Navigator.pop(context);
                      await Future.delayed(const Duration(milliseconds: 300));
                      _pickMonth();
                    },
                  ),
                  const SizedBox(height: 12),

                  _buildEnhancedFilterOption(
                    icon: PhosphorIcons.clock(),
                    text: "Year Only",
                    subText: "Filter by entire year",
                    isSelected: _filterType == FilterType.year,
                    onTap: () async {
                      setModalState(() => _filterType = FilterType.year);
                      await Future.delayed(const Duration(milliseconds: 150));
                      if (context.mounted) Navigator.pop(context);
                      await Future.delayed(const Duration(milliseconds: 300));
                      _pickYear();
                    },
                  ),

                  SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // 2. Widget Option Card
  Widget _buildEnhancedFilterOption({
    required IconData icon,
    required String text,
    required String subText,
    required VoidCallback onTap,
    required bool isSelected,
  }) {
    final bgColor = isSelected ? const Color(0xFFF0F6FF) : Colors.white;
    final borderColor = isSelected
        ? const Color(0xFF2260FF)
        : const Color(0xFFF3F4F6);
    final iconCircleColor = isSelected
        ? const Color(0xFF2260FF)
        : const Color(0xFFF9FAFB);
    final iconColor = isSelected ? Colors.white : const Color(0xFF6B7280);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: [
            if (!isSelected)
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconCircleColor,
                shape: BoxShape.circle,
                border: isSelected
                    ? null
                    : Border.all(color: const Color(0xFFE5E7EB), width: 1),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: isSelected
                          ? const Color(0xFF111827)
                          : const Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subText,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w400,
                      fontSize: 13,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ),
            AnimatedOpacity(
              opacity: isSelected ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
                color: const Color(0xFF2260FF),
                size: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 3. Các hàm Picker
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
      helpText: 'SELECT DATE',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF2260FF)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _filterType = FilterType.date;
        _selectedDate = picked;
      });
      _fetchRequests();
    }
  }

  Future<void> _pickYear() async {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            "Select Year",
            style: TextStyle(fontFamily: 'Inter'),
          ),
          content: SizedBox(
            width: 300,
            height: 300,
            child: YearPicker(
              firstDate: DateTime(2020),
              lastDate: DateTime(DateTime.now().year + 1),
              selectedDate: _selectedDate ?? DateTime.now(),
              onChanged: (DateTime val) {
                setState(() {
                  _filterType = FilterType.year;
                  _selectedDate = val;
                });
                _fetchRequests();
                Navigator.pop(context);
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickMonth() async {
    int tempYear = _selectedDate?.year ?? DateTime.now().year;
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            "Select Year",
            style: TextStyle(fontFamily: 'Inter'),
          ),
          content: SizedBox(
            width: 300,
            height: 300,
            child: YearPicker(
              firstDate: DateTime(2020),
              lastDate: DateTime(DateTime.now().year + 1),
              selectedDate: DateTime(tempYear),
              onChanged: (val) {
                Navigator.pop(context);
                _pickMonthStep2(val.year);
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickMonthStep2(int year) async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            "Select Month ($year)",
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: List.generate(12, (index) {
                return InkWell(
                  onTap: () {
                    setState(() {
                      _filterType = FilterType.month;
                      _selectedDate = DateTime(year, index + 1, 1);
                    });
                    _fetchRequests();
                    Navigator.pop(context);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white,
                    ),
                    child: Text(
                      DateFormat('MMM').format(DateTime(2023, index + 1)),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        );
      },
    );
  }

  void _clearFilter() {
    setState(() {
      _filterType = FilterType.none;
      _selectedDate = null;
    });
    _fetchRequests();
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
        // [MỚI] Cập nhật UI để hiện/ẩn nút X khi gõ
        onChanged: (val) {
          _onSearchChanged(val);
          setState(() {});
        },
        decoration: InputDecoration(
          hintText: 'Search requests...',
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
          // [MỚI] Nút Xóa hình tròn (Đồng bộ giao diện)
          suffixIcon: _searchController.text.isNotEmpty
              ? Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      setState(() {}); // Cập nhật UI ẩn nút X

                      // Hủy debounce cũ và load lại danh sách gốc ngay lập tức
                      if (_debounce?.isActive ?? false) _debounce!.cancel();
                      _fetchRequests();
                    },
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFFC4C4C4), // Màu nền xám
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        PhosphorIcons.x(PhosphorIconsStyle.bold),
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    String message = _searchController.text.isNotEmpty
        ? "No requests found matching '${_searchController.text}'"
        : "No requests found";

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // [ĐÃ SỬA] Dùng Icon Clipboard có dấu tick để giống ảnh mẫu
          Icon(
            PhosphorIcons.clipboardText(PhosphorIconsStyle.regular),
            size: 64, // Kích thước lớn hơn chút cho rõ
            color: const Color(0xFFE5E7EB), // Màu xám rất nhạt (giống ảnh)
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              color: Color(0xFF9CA3AF), // Màu chữ xám vừa phải
              fontSize: 16,
              fontWeight: FontWeight.w500,
              fontFamily: 'Inter',
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // [CẬP NHẬT] Nút Filter có hiệu ứng nhấn (Ripple Effect)
  Widget _buildFilterButton() {
    final bool hasFilter =
        _filterType != FilterType.none && _selectedDate != null;
    String dateText = '';

    if (hasFilter) {
      if (_filterType == FilterType.date) {
        dateText = DateFormat('dd/MM/yyyy').format(_selectedDate!);
      } else if (_filterType == FilterType.month) {
        dateText = DateFormat('MM/yyyy').format(_selectedDate!);
      } else if (_filterType == FilterType.year) {
        dateText = DateFormat('yyyy').format(_selectedDate!);
      }
    }

    // Màu sắc nền và viền
    final bgColor = hasFilter
        ? const Color(0xFFECF1FF)
        : const Color(0xFFF5F5F5);
    final borderColor = hasFilter
        ? const Color(0xFF2260FF)
        : const Color(0xFFE0E0E0);

    return Material(
      color: bgColor,

      // Tạo viền thông qua Shape của Material để không bị InkWell đè lên
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: 1),
      ),
      child: InkWell(
        onTap: _onFilterTap,
        borderRadius: BorderRadius.circular(12),
        // Mới (Màu xám)
        splashColor: Colors.grey.withOpacity(0.2),
        highlightColor: Colors.grey.withOpacity(0.1),
        child: Container(
          // Tự co giãn nếu có text, nếu không thì cố định 45
          width: hasFilter ? null : 45,
          height: 45,
          padding: EdgeInsets.symmetric(horizontal: hasFilter ? 12 : 0),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hasFilter
                    ? PhosphorIconsFill.funnel
                    : PhosphorIconsRegular.funnel,
                color: hasFilter
                    ? const Color(0xFF2260FF)
                    : const Color(0xFF555252),
                size: 20,
              ),
              if (hasFilter) ...[
                const SizedBox(width: 8),
                Text(
                  dateText,
                  style: const TextStyle(
                    color: Color(0xFF2260FF),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(width: 8),
                // Nút xóa dùng GestureDetector riêng để không kích hoạt InkWell cha
                GestureDetector(
                  onTap: _clearFilter,
                  child: const Icon(
                    Icons.close,
                    size: 18,
                    color: Color(0xFF2260FF),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // List được filter client-side (theo Tab)
  List<RequestModel> get _filteredRequests {
    if (_selectedFilter == 'All') return _requests;
    return _requests
        .where(
          (r) => r.statusText.toUpperCase() == _selectedFilter.toUpperCase(),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateRequestPage()),
          );
          if (result == true) {
            _fetchRequests();
          }
        },
        backgroundColor: AppColors.primary,
        shape: const CircleBorder(),
        elevation: 4,
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),

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
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            PhosphorIcons.caretLeft(PhosphorIconsStyle.bold),
                            color: AppColors.primary,
                            size: 24,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const Text(
                        'MY REQUESTS',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 24,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                // Search & Filter (Đã cập nhật UI mới)
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

                const SizedBox(height: 20),
                // Filter Tabs (Giữ nguyên)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: ['All', 'Pending', 'Approved', 'Rejected'].map((
                      status,
                    ) {
                      final isSelected = _selectedFilter == status;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedFilter = status),
                        child: Container(
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFFE5E5E5).withOpacity(0.5),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : [],
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              color: isSelected
                                  ? AppColors.primary
                                  : const Color(0xFF9CA3AF),
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 24),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'HISTORY',
                      style: TextStyle(
                        color: Color(0xFF655F5F),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // List Items
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _filteredRequests.isEmpty
                      // [ĐÃ SỬA] Gọi hàm hiển thị rỗng đồng bộ
                      ? _buildEmptyState()
                      // [ĐÃ SỬA] Đồng bộ giao diện "Rỗng" giống trang Manager
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 8,
                          ),
                          itemCount: _filteredRequests.length,
                          itemBuilder: (context, index) {
                            final request = _filteredRequests[index];

                            // LOGIC HIỂN THỊ HEADER THÁNG
                            final date = request.createdAt ?? request.startTime;
                            bool showHeader = false;

                            if (index == 0) {
                              showHeader = true;
                            } else {
                              final prevRequest = _filteredRequests[index - 1];
                              final prevDate =
                                  prevRequest.createdAt ??
                                  prevRequest.startTime;
                              if (date.month != prevDate.month ||
                                  date.year != prevDate.year) {
                                showHeader = true;
                              }
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (showHeader)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: 16,
                                      bottom: 12,
                                    ),
                                    child: Text(
                                      DateFormat('MMMM yyyy').format(date),
                                      style: const TextStyle(
                                        color: Color(0xFF6B7280),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        fontFamily: 'Inter',
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),

                                Dismissible(
                                  key: Key(request.id.toString()),
                                  direction: DismissDirection.endToStart,
                                  background: Container(
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 24),
                                    margin: const EdgeInsets.only(bottom: 16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEE2E2),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFEF4444),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                  confirmDismiss: (direction) async {
                                    return await showDialog(
                                      context: context,
                                      builder: (context) => _buildConfirmDialog(
                                        context,
                                        isPending:
                                            request.status ==
                                            RequestStatus.PENDING,
                                      ),
                                    );
                                  },
                                  onDismissed: (direction) async {
                                    setState(() {
                                      _requests.removeWhere(
                                        (item) => item.id == request.id,
                                      );
                                    });
                                    try {
                                      final userId =
                                          await _getUserIdFromStorage();
                                      if (userId != null) {
                                        await _repository.cancelRequest(
                                          request.id.toString(),
                                          userId,
                                        );
                                      }
                                    } catch (e) {
                                      print("Lỗi xóa đơn: $e");
                                    }
                                  },
                                  child: _buildRequestCard(request),
                                ),
                              ],
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

  Widget _buildRequestCard(RequestModel request) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RequestDetailPage(request: request),
              ),
            );
            if (result == true) {
              _fetchRequests();
            }
          },
          child: IntrinsicHeight(
            child: Row(
              children: [
                Container(width: 6, color: request.statusColor),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              request.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                                fontFamily: 'Inter',
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: request.statusBgColor,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                request.statusText,
                                style: TextStyle(
                                  color: request.statusColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'Inter',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          request.description,
                          style: const TextStyle(
                            color: Color(0xFF52525B),
                            fontSize: 13,
                            height: 1.4,
                            fontFamily: 'Inter',
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              request.dateRange,
                              style: const TextStyle(
                                color: Color(0xFFA1A1AA),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Inter',
                              ),
                            ),
                            Text(
                              request.duration,
                              style: const TextStyle(
                                color: Color(0xFFA1B9D5),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ],
                        ),
                      ],
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

  // --- WIDGET DIALOG ---
  Widget _buildConfirmDialog(BuildContext context, {required bool isPending}) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFDC2626),
                  size: 32,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isPending ? "Cancel Request?" : "Hide from History?",
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                fontFamily: 'Inter',
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isPending
                  ? "Are you sure you want to cancel this request? This action cannot be undone."
                  : "This request will be hidden from your list but still kept in company records.",
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontFamily: 'Inter',
                color: Color(0xFF6B7280),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: const Color(0xFFF3F4F6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "No, Keep it",
                      style: TextStyle(
                        color: Color(0xFF374151),
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: const Color(0xFFDC2626),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      isPending ? "Yes, Cancel" : "Yes, Hide",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
