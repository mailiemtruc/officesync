import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Import Service mới
import '../../../../core/services/websocket_service.dart';
import '../../../../core/config/app_colors.dart';
import '../../data/models/request_model.dart';
import 'manager_request_review_page.dart';
import '../../data/datasources/request_remote_data_source.dart';

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

  List<Map<String, dynamic>> _requestList = [];

  @override
  void initState() {
    super.initState();
    _fetchRequests();
    _setupSocketListener();
  }

  @override
  void dispose() {
    // [QUAN TRỌNG] Hủy đăng ký khi thoát màn hình để tránh leak
    if (_unsubscribeFn != null) {
      _unsubscribeFn(unsubscribeHeaders: {});
    }
    super.dispose();
  }

  // Đăng ký lắng nghe từ Service chung
  Future<void> _setupSocketListener() async {
    String? userInfoStr = await _storage.read(key: 'user_info');
    if (userInfoStr != null) {
      final userMap = jsonDecode(userInfoStr);
      _currentCompanyId = userMap['companyId']?.toString();
    }

    if (_currentCompanyId != null) {
      final topic = '/topic/company/$_currentCompanyId/requests';

      // Gọi service global
      _unsubscribeFn = WebSocketService().subscribe(topic, (data) {
        if (!mounted) return;

        // 1. Nếu nhận được chuỗi "NEW_REQUEST" -> Reload API
        if (data is String && data == "NEW_REQUEST") {
          _fetchRequests(isBackgroundRefresh: true);
        }
        // 2. Nếu nhận được JSON Object -> Update UI trực tiếp
        else if (data is Map<String, dynamic>) {
          try {
            final updatedReq = RequestModel.fromJson(data);
            setState(() {
              final index = _requestList.indexWhere(
                (item) => (item['request'] as RequestModel).id == updatedReq.id,
              );

              if (index != -1) {
                // Update item có sẵn
                _requestList[index]['request'] = updatedReq;
                // Cập nhật lại status text/color nếu cần thiết
                _requestList[index]['status'] = updatedReq.status.name;
              } else {
                // Nếu không tìm thấy (trường hợp hiếm), reload lại cho chắc
                _fetchRequests(isBackgroundRefresh: true);
              }
            });
          } catch (e) {
            print("Socket Parse Error: $e");
          }
        }
      });
    }
  }

  Future<void> _fetchRequests({bool isBackgroundRefresh = false}) async {
    if (!isBackgroundRefresh) setState(() => _isLoading = true);

    try {
      String? userId;
      String? userInfoStr = await _storage.read(key: 'user_info');
      if (userInfoStr != null) {
        try {
          final userMap = jsonDecode(userInfoStr);
          userId = userMap['id']?.toString();
        } catch (_) {}
      }
      if (userId == null) userId = await _storage.read(key: 'user_id');

      if (userId != null) {
        List<RequestModel> requests = await _dataSource.getManagerRequests(
          userId,
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
              };
            }).toList();
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ... (Giữ nguyên phần UI build, _onBottomNavTap, _buildTabs...)
  // Lưu ý: Không thay đổi phần UI code phía dưới

  void _onBottomNavTap(int index) {
    // ... Code cũ giữ nguyên
    switch (index) {
      case 0:
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/dashboard',
          (route) => false,
        );
        break;
      case 1:
        break;
      case 2:
        Navigator.pushNamed(context, '/user_profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Filter danh sách hiển thị theo Tab hiện tại (Logic cũ giữ nguyên)
    final displayList = _requestList.where((item) {
      final req = item['request'] as RequestModel;
      if (_isToReviewTab) {
        return req.status == RequestStatus.PENDING;
      } else {
        return req.status != RequestStatus.PENDING;
      }
    }).toList();

    // 2. [SỬA LỖI] Tính riêng số lượng đơn PENDING từ danh sách gốc
    // Để con số này không bị đổi khi chuyển Tab
    final int pendingCount = _requestList.where((item) {
      final req = item['request'] as RequestModel;
      return req.status == RequestStatus.PENDING;
    }).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.white,
          currentIndex: 1,
          onTap: _onBottomNavTap,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          items: [
            BottomNavigationBarItem(
              icon: Icon(PhosphorIconsRegular.house),
              activeIcon: Icon(PhosphorIconsFill.house),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(PhosphorIconsFill.squaresFour),
              activeIcon: Icon(PhosphorIconsFill.squaresFour),
              label: 'Menu',
            ),
            BottomNavigationBarItem(
              icon: Icon(PhosphorIconsRegular.user),
              activeIcon: Icon(PhosphorIconsFill.user),
              label: 'Profile',
            ),
          ],
        ),
      ),
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
                  // 3. [SỬA LỖI] Truyền pendingCount tính riêng ở trên vào đây
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
                      _isToReviewTab ? 'TODAY' : 'HISTORY',
                      style: const TextStyle(
                        color: Color(0xFF655F5F),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : displayList.isEmpty
                      ? const Center(child: Text("No requests found"))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 8,
                          ),
                          itemCount: displayList.length,
                          itemBuilder: (context, index) {
                            final item = displayList[index];
                            return _ManagerRequestCard(
                              data: item,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        ManagerRequestReviewPage(
                                          request: item['request'],
                                        ),
                                  ),
                                );
                              },
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
              label: 'To review', // Chỉ để label text
              count: pendingCount, // Truyền count vào để hiển thị badge
              isActive: _isToReviewTab,
              onTap: () => setState(() => _isToReviewTab = true),
            ),
          ),
          Expanded(
            child: _buildTabItem(
              label: 'History',
              count: null, // History không hiện badge
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
    // Màu văn bản chính
    final baseColor = isActive
        ? const Color(0xE52260FF)
        : const Color(0xFFB2AEAE);

    // Xử lý logic hiển thị số: Nếu > 100 thì hiện "99+"
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
            // Nếu có badgeText (tức là count > 0) thì hiển thị Badge đỏ
            if (badgeText != null) ...[
              const SizedBox(width: 6),
              Container(
                // [FIX LỖI] Ép chiều cao cố định để không bị méo thành hình bầu dục dọc
                height: 20,
                constraints: const BoxConstraints(
                  minWidth:
                      20, // Chiều rộng tối thiểu bằng chiều cao -> Hình tròn
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                ), // Chỉ padding ngang
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444), // Nền đỏ
                  borderRadius: BorderRadius.circular(
                    10,
                  ), // Bo tròn = height / 2
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
                    height: 1.1, // Căn chỉnh dòng để chữ nằm giữa
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
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0x33C7C5C5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD7D2D2)),
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search name, employee ID...',
          hintStyle: const TextStyle(
            color: Color(0xFF706464),
            fontSize: 15,
            fontWeight: FontWeight.w300,
            fontFamily: 'Inter',
          ),
          prefixIcon: Icon(
            PhosphorIcons.magnifyingGlass(),
            color: const Color(0xFF706464),
            size: 20,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
        ),
      ),
    );
  }

  Widget _buildFilterButton() {
    return Container(
      width: 40,
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0x33C7C5C5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD7D2D2)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {},
          child: Center(
            child: Icon(
              PhosphorIcons.funnel(PhosphorIconsStyle.regular),
              color: const Color(0xFF706464),
              size: 20,
            ),
          ),
        ),
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
    final bool isManager = ['001', '004'].contains(data['employeeId']);
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
                // --- BẮT ĐẦU ĐOẠN SỬA ---
                Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFF3F4F6), // Nền xám nhạt
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
                              return const Center(
                                child: Icon(
                                  Icons.person,
                                  color: Color(0xFF9CA3AF),
                                  size: 24,
                                ),
                              );
                            },
                          ),
                        )
                      : const Center(
                          child: Icon(
                            Icons.person,
                            color: Color(0xFF9CA3AF),
                            size: 24,
                          ),
                        ),
                ),
                // --- KẾT THÚC ĐOẠN SỬA ---
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
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFECF1FF),
                                          borderRadius: BorderRadius.circular(
                                            5,
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
                          fontWeight: FontWeight.w300,
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
                                fontWeight: FontWeight.w300,
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
