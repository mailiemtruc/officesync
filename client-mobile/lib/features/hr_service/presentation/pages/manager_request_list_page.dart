import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'dart:async';

// Import các file của bạn (Giữ nguyên)
import '../../../../core/services/websocket_service.dart';
import '../../../../core/config/app_colors.dart';
import '../../data/models/request_model.dart';
import 'manager_request_review_page.dart';
import '../../data/datasources/request_remote_data_source.dart';
import '../../widgets/skeleton_request_card.dart';

enum FilterType { none, date, month, year }

class ManagerRequestListPage extends StatefulWidget {
  const ManagerRequestListPage({super.key});

  @override
  State<ManagerRequestListPage> createState() => _ManagerRequestListPageState();
}

class _ManagerRequestListPageState extends State<ManagerRequestListPage> {
  bool _isToReviewTab = true;
  bool _isLoading = true;
  final _storage = const FlutterSecureStorage();
  final _dataSource = RequestRemoteDataSource();

  // Biến lưu hàm hủy đăng ký
  dynamic _unsubscribeFn;
  String? _currentCompanyId;

  // [LOGIC MỚI 1] Biến lưu Role người dùng hiện tại
  String _currentUserRole = '';

  List<Map<String, dynamic>> _requestList = [];

  // Biến phục vụ tìm kiếm Server-side
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  // Biến lọc thời gian
  DateTime? _selectedDate;
  FilterType _filterType = FilterType.none;

  @override
  void initState() {
    super.initState();
    _fetchRequests();
    _setupSocketListener();
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

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      if (mounted) {
        _fetchRequests();
      }
    });
  }

  Future<void> _setupSocketListener() async {
    String? userInfoStr = await _storage.read(key: 'user_info');
    if (userInfoStr != null) {
      final userMap = jsonDecode(userInfoStr);
      _currentCompanyId = userMap['companyId']?.toString();
    }

    // URL chuẩn của HR Service
    final String hrSocketUrl = 'ws://10.0.2.2:8081/ws-hr';

    if (_currentCompanyId != null) {
      final topic = '/topic/company/$_currentCompanyId/requests';

      _unsubscribeFn = WebSocketService().subscribe(topic, (data) {
        if (!mounted) return;
        print("--> Socket received update. Reloading list...");
        _fetchRequests(isBackgroundRefresh: true);
      }, forceUrl: hrSocketUrl);
    }
  }

  Future<void> _fetchRequests({bool isBackgroundRefresh = false}) async {
    if (!mounted) return;

    if (!isBackgroundRefresh) setState(() => _isLoading = true);

    try {
      String? userId;
      String? userInfoStr = await _storage.read(key: 'user_info');

      if (userInfoStr != null) {
        try {
          final userMap = jsonDecode(userInfoStr);
          userId = userMap['id']?.toString();

          // [LOGIC MỚI 2] Lấy Role từ token/storage
          // Nếu không có key 'role', mặc định là EMPLOYEE
          _currentUserRole = userMap['role']?.toString() ?? 'STAFF';
        } catch (e) {
          print("Error parsing user info: $e");
        }
      }
      if (userId == null) {
        userId = await _storage.read(key: 'user_id');
      }

      if (userId != null) {
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

        // Gọi API tìm kiếm
        List<RequestModel> requests = await _dataSource.getManagerRequests(
          userId,
          search: _searchController.text,
          day: d,
          month: m,
          year: y,
        );

        if (mounted) {
          setState(() {
            _requestList = requests.map((req) {
              return {
                'request': req,
                'id': req.id,
                'employeeName': req.requesterName.isNotEmpty
                    ? req.requesterName
                    : 'Unknown',
                'employeeId': req.requesterId,
                'dept': req.requesterDept.isNotEmpty
                    ? req.requesterDept
                    : 'N/A',
                'avatar': req.requesterAvatar,
                'timeInfo': req.duration,
                'processedDate': '',
                'status': req.status.name,
              };
            }).toList();

            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      print("Error fetching requests: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // [CẬP NHẬT] Hàm kiểm tra quyền duyệt đơn (An toàn hơn)
  bool _canReview(RequestModel req) {
    // 1. Chỉ quan tâm đơn PENDING
    if (req.status != RequestStatus.PENDING) return false;

    // 2. Nếu mình là ADMIN -> Có quyền duyệt tất cả
    final myRoleClean = _currentUserRole.toUpperCase().trim();
    if (myRoleClean == 'COMPANY_ADMIN') return true;

    // [FIX QUAN TRỌNG] Xử lý trường hợp role bị null do lỗi backend
    // Nếu role người gửi bị null/empty -> Mặc định coi là nguy hiểm -> Trả về FALSE (về History)
    // Để tránh việc HR lỡ tay duyệt đơn của Manager
    if (req.requesterRole == null || req.requesterRole!.isEmpty) {
      print(
        "--> WARNING: Request ID ${req.id} has missing Role data. Moved to History for safety.",
      );
      return false;
    }

    // 3. Nếu người tạo đơn là MANAGER -> HR không được duyệt
    final requesterRoleClean = req.requesterRole!.toUpperCase().trim();
    if (requesterRoleClean == 'MANAGER') {
      return false;
    }

    // 4. Các trường hợp còn lại (HR duyệt Staff) -> True
    return true;
  }

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
                  Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Filter Requests",
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            child: const Text(
                              "Reset ",
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildEnhancedFilterOption(
                    icon: PhosphorIcons.calendar(),
                    text: "Specific Date",
                    subText: "Filter by a specific day (e.g. 25 Oct)",
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
                    subText: "Filter by month (e.g. October 2023)",
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
                    subText: "Filter by entire year (e.g. 2023)",
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

  void _clearFilter() {
    setState(() {
      _filterType = FilterType.none;
      _selectedDate = null;
    });
    _fetchRequests();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
      helpText: 'SELECT DATE',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ),
          child: child!,
        );
      },
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
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onSurface: Colors.black,
            ),
          ),
          child: AlertDialog(
            title: const Text(
              "Select Year",
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.bold,
              ),
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
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onSurface: Colors.black,
            ),
          ),
          child: AlertDialog(
            title: const Text(
              "Select Year",
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.bold,
              ),
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
          ),
        );
      },
    );
  }

  Future<void> _pickMonthStep2(int year) async {
    await showDialog(
      context: context,
      builder: (context) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onSurface: Colors.black,
            ),
          ),
          child: AlertDialog(
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
                    splashColor: AppColors.primary.withOpacity(0.1),
                    highlightColor: AppColors.primary.withOpacity(0.05),
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
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // [LOGIC MỚI 4] Lọc danh sách hiển thị dựa trên cả Status và Quyền hạn
    final displayList = _requestList.where((item) {
      final req = item['request'] as RequestModel;

      // Sử dụng hàm _canReview để check quyền
      final bool hasPermission = _canReview(req);

      if (_isToReviewTab) {
        // Tab TO REVIEW: Chỉ hiện đơn PENDING và CÓ QUYỀN DUYỆT
        // (Đơn Manager sẽ bị loại bỏ ở đây)
        return req.status == RequestStatus.PENDING && hasPermission;
      } else {
        // Tab HISTORY: Hiện đơn ĐÃ XỬ LÝ hoặc đơn PENDING MÀ KHÔNG CÓ QUYỀN (View only)
        // (Đơn Manager sẽ hiện ở đây)
        return req.status != RequestStatus.PENDING ||
            (req.status == RequestStatus.PENDING && !hasPermission);
      }
    }).toList();

    // [LOGIC MỚI 5] Đếm badge chỉ cho những đơn cần mình duyệt
    final int pendingCount = _requestList.where((item) {
      final req = item['request'] as RequestModel;
      return req.status == RequestStatus.PENDING && _canReview(req);
    }).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                const SizedBox(height: 20),
                _buildHeader(context),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _buildTabs(pendingCount),
                ),
                const SizedBox(height: 24),
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
                const SizedBox(height: 24),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _isToReviewTab ? 'PENDING REQUESTS' : 'HISTORY',
                      style: const TextStyle(
                        color: Color(0xFF655F5F),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Inter',
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),

                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) =>
                        FadeTransition(opacity: animation, child: child),
                    child: _buildBodyContent(displayList),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBodyContent(List<Map<String, dynamic>> displayList) {
    Widget content;
    Key contentKey;

    if (_isLoading) {
      contentKey = const ValueKey('loading_skeleton');
      content = ListView.builder(
        padding: const EdgeInsets.only(top: 10),
        itemCount: 6,
        itemBuilder: (context, index) => const SkeletonRequestCard(),
      );
    } else if (displayList.isEmpty) {
      contentKey = ValueKey('empty_${_isToReviewTab ? "review" : "history"}');
      content = RefreshIndicator(
        onRefresh: () async => await _fetchRequests(isBackgroundRefresh: true),
        color: const Color(0xFF2260FF),
        child: Stack(
          children: [
            ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.3),
              ],
            ),
            Positioned.fill(child: _buildEmptyState()),
          ],
        ),
      );
    } else {
      contentKey = ValueKey('data_${_isToReviewTab ? "review" : "history"}');
      content = RefreshIndicator(
        onRefresh: () async => await _fetchRequests(isBackgroundRefresh: true),
        color: const Color(0xFF2260FF),
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          itemCount: displayList.length,
          itemBuilder: (context, index) {
            final item = displayList[index];
            final request = item['request'] as RequestModel;
            final date = request.createdAt ?? request.startTime;
            bool showHeader = false;

            if (index == 0) {
              showHeader = true;
            } else {
              final prevItem = displayList[index - 1];
              final prevRequest = prevItem['request'] as RequestModel;
              final prevDate = prevRequest.createdAt ?? prevRequest.startTime;
              if (date.month != prevDate.month || date.year != prevDate.year) {
                showHeader = true;
              }
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showHeader)
                  Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 12),
                    child: Text(
                      DateFormat('MMMM yyyy').format(date),
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                _ManagerRequestCard(
                  data: item,
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ManagerRequestReviewPage(request: item['request']),
                      ),
                    );
                    if (result == true) {
                      if (mounted) _fetchRequests(isBackgroundRefresh: true);
                    }
                  },
                ),
              ],
            );
          },
        ),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 50),
      switchInCurve: Curves.easeIn,
      switchOutCurve: Curves.easeOut,
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: KeyedSubtree(key: contentKey, child: content),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
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
                color: const Color(0xFF2260FF),
                size: 24,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const Text(
            'REQUEST MANAGEMENT',
            style: TextStyle(
              color: Color(0xFF2260FF),
              fontSize: 24,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs(int pendingCount) {
    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0x72E6E5E5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabItem(
              label: 'To review',
              count: pendingCount,
              isActive: _isToReviewTab,
              onTap: () => setState(() => _isToReviewTab = true),
            ),
          ),
          Expanded(
            child: _buildTabItem(
              label: 'History',
              count: null,
              isActive: !_isToReviewTab,
              onTap: () => setState(() => _isToReviewTab = false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem({
    required String label,
    int? count,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final baseColor = isActive
        ? const Color(0xE52260FF)
        : const Color(0xFFB2AEAE);

    String? badgeText;
    if (count != null && count > 0) {
      badgeText = count > 100 ? '99+' : count.toString();
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: baseColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: 'Inter',
              ),
            ),
            if (badgeText != null) ...[
              const SizedBox(width: 6),
              Container(
                height: 20,
                constraints: const BoxConstraints(minWidth: 20),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  badgeText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Inter',
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ],
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
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: TextField(
        controller: _searchController,
        // [FIX] Bỏ setState ở đây
        onChanged: (val) => _onSearchChanged(val),
        decoration: InputDecoration(
          hintText: 'Search requests...',
          hintStyle: const TextStyle(
            color: Color(0xFF9E9E9E),
            fontSize: 14,
            fontWeight: FontWeight.w300,
            fontFamily: 'Inter',
          ),
          prefixIcon: Icon(
            PhosphorIcons.magnifyingGlass(),
            color: const Color(0xFF757575),
            size: 20,
          ),
          // [FIX] Dùng ValueListenableBuilder cho nút X
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _searchController,
            builder: (context, value, child) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.all(10.0),
                child: GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    if (_debounce?.isActive ?? false) _debounce!.cancel();
                    _fetchRequests();
                  },
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFFC4C4C4),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      PhosphorIcons.x(PhosphorIconsStyle.bold),
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              );
            },
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

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

    final bgColor = hasFilter
        ? const Color(0xFFECF1FF)
        : const Color(0xFFF5F5F5);
    final borderColor = hasFilter
        ? const Color(0xFF2260FF)
        : const Color(0xFFE0E0E0);

    return Material(
      color: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: 1),
      ),
      child: InkWell(
        onTap: _onFilterTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: Colors.grey.withOpacity(0.2),
        highlightColor: Colors.grey.withOpacity(0.1),
        child: Container(
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

  Widget _buildEmptyState() {
    String message = _searchController.text.isNotEmpty
        ? "No requests found matching '${_searchController.text}'"
        : "No requests found";

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            PhosphorIcons.clipboardText(PhosphorIconsStyle.regular),
            size: 64,
            color: const Color(0xFFE5E7EB),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              color: Color(0xFF9CA3AF),
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
}

class _ManagerRequestCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  const _ManagerRequestCard({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final RequestModel request = data['request'];
    final String timeInfo = data['timeInfo'] ?? request.duration;
    final bool isManager =
        request.requesterRole == 'MANAGER' ||
        request.requesterRole == 'COMPANY_ADMIN';
    final String processedDate = data['processedDate'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(width: 1, color: const Color(0x4CF1F1F1)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 10,
            offset: Offset(0, 0),
            spreadRadius: 2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFF3F4F6),
                  ),
                  child:
                      (data['avatar'] != null &&
                          data['avatar'].toString().isNotEmpty)
                      ? ClipOval(
                          child: Image.network(
                            data['avatar'],
                            width: 46,
                            height: 46,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Icon(
                                  PhosphorIcons.user(PhosphorIconsStyle.fill),
                                  color: const Color(0xFF9CA3AF),
                                  size: 24,
                                ),
                              );
                            },
                          ),
                        )
                      : Center(
                          child: Icon(
                            PhosphorIcons.user(PhosphorIconsStyle.fill),
                            color: const Color(0xFF9CA3AF),
                            size: 24,
                          ),
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: data['employeeName'],
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'Inter',
                                      color: Colors.black,
                                    ),
                                  ),
                                  if (isManager) ...[
                                    const TextSpan(text: ' '),
                                    WidgetSpan(
                                      alignment: PlaceholderAlignment.middle,
                                      child: Container(
                                        margin: const EdgeInsets.only(left: 4),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFECF1FF),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: const Text(
                                          'Manager',
                                          style: TextStyle(
                                            color: Color(0xFF2260FF),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            fontFamily: 'Inter',
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getExactStatusBgColor(request.status),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Text(
                              request.status.name,
                              style: TextStyle(
                                color: _getExactStatusColor(request.status),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Employee ID: ${data['employeeId']} | ${data['dept']}',
                        style: const TextStyle(
                          color: Color(0xFF555252),
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          fontFamily: 'Inter',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      RichText(
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: request.type.name,
                              style: const TextStyle(
                                color: Color(0xFF2563EB),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Inter',
                              ),
                            ),
                            const TextSpan(
                              text: '    ',
                              style: TextStyle(fontSize: 13),
                            ),
                            TextSpan(
                              text: timeInfo,
                              style: const TextStyle(
                                color: Color(0xFF555252),
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (processedDate.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          processedDate,
                          style: const TextStyle(
                            color: Color(0xFF555252),
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  PhosphorIcons.caretRight(),
                  size: 20,
                  color: const Color(0xFF9CA3AF),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getExactStatusBgColor(RequestStatus status) {
    switch (status) {
      case RequestStatus.PENDING:
        return const Color(0xFFFFF7ED);
      case RequestStatus.REJECTED:
        return const Color(0xFFFEF2F2);
      case RequestStatus.APPROVED:
        return const Color(0xFFF0FDF4);
      default:
        return const Color(0xFFF3F4F6);
    }
  }

  Color _getExactStatusColor(RequestStatus status) {
    switch (status) {
      case RequestStatus.PENDING:
        return const Color(0xFFEA580C);
      case RequestStatus.REJECTED:
        return const Color(0xFFDC2626);
      case RequestStatus.APPROVED:
        return const Color(0xFF16A34A);
      default:
        return const Color(0xFF374151);
    }
  }
}
