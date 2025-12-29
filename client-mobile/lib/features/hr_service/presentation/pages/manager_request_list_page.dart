import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// [MỚI] Import thư viện WebSocket
import 'package:stomp_dart_client/stomp.dart';
import 'package:stomp_dart_client/stomp_config.dart';
import 'package:stomp_dart_client/stomp_frame.dart';

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

  // [MỚI] Biến Client WebSocket
  StompClient? client;
  String? _currentCompanyId;

  // Dữ liệu lấy từ API
  List<Map<String, dynamic>> _requestList = [];

  @override
  void initState() {
    super.initState();
    _fetchRequests();
    _initWebSocket(); // [MỚI] Bắt đầu kết nối Socket
  }

  @override
  void dispose() {
    client?.deactivate(); // [MỚI] Ngắt kết nối khi thoát màn hình
    super.dispose();
  }

  // [HÀM MỚI] Cấu hình WebSocket Realtime
  Future<void> _initWebSocket() async {
    try {
      // 1. Lấy CompanyID
      String? userInfoStr = await _storage.read(key: 'user_info');
      if (userInfoStr != null) {
        final userMap = jsonDecode(userInfoStr);
        _currentCompanyId = userMap['companyId']?.toString();
      }

      if (_currentCompanyId == null) return;

      final socketUrl = 'ws://10.0.2.2:8081/ws-hr/websocket';

      client = StompClient(
        config: StompConfig(
          url: socketUrl,
          onConnect: (StompFrame frame) {
            print("--> [WebSocket] Connected!");

            // Topic: /topic/company/{id}/requests
            final topic = '/topic/company/$_currentCompanyId/requests';

            client?.subscribe(
              destination: topic,
              callback: (StompFrame frame) {
                if (frame.body != null) {
                  print("--> [WebSocket] Msg: ${frame.body}");

                  // [LOGIC THÔNG MINH HƠN]
                  // Nếu là chuỗi thông báo "NEW_REQUEST" -> Load lại cả list
                  if (frame.body == "NEW_REQUEST") {
                    if (mounted) _fetchRequests(isBackgroundRefresh: true);
                  }
                  // Nếu là JSON object -> Update item cụ thể
                  else {
                    try {
                      final dynamic data = jsonDecode(frame.body!);
                      final updatedReq = RequestModel.fromJson(data);

                      if (mounted) {
                        setState(() {
                          // Tìm request trong list hiện tại
                          final index = _requestList.indexWhere(
                            (item) =>
                                (item['request'] as RequestModel).id ==
                                updatedReq.id,
                          );

                          if (index != -1) {
                            // Cập nhật object request mới vào map cũ
                            _requestList[index]['request'] = updatedReq;

                            // Nếu muốn update cả timeInfo/processedDate nếu cần
                            // _requestList[index]['timeInfo'] = updatedReq.duration;
                          } else {
                            // Trường hợp hiếm: Socket báo về đơn mới mà không gửi chuỗi "NEW_REQUEST"
                            // Ta thêm vào đầu list luôn
                            // (Cần cấu trúc Map giống hệt _fetchRequests)
                            _fetchRequests(isBackgroundRefresh: true);
                          }
                        });
                      }
                    } catch (e) {
                      // Fallback: Nếu parse lỗi thì cứ load lại API cho chắc
                      if (mounted) _fetchRequests(isBackgroundRefresh: true);
                    }
                  }
                }
              },
            );
          },
          onWebSocketError: (dynamic error) =>
              print("--> [WebSocket] Error: $error"),
        ),
      );

      client?.activate();
    } catch (e) {
      print("--> [WebSocket] Init Error: $e");
    }
  }

  // [SỬA] Thêm tham số isBackgroundRefresh
  Future<void> _fetchRequests({bool isBackgroundRefresh = false}) async {
    if (!isBackgroundRefresh) {
      setState(() => _isLoading = true);
    }

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

      if (userId == null) {
        setState(() => _isLoading = false);
        return;
      }

      List<RequestModel> requests = await _dataSource.getManagerRequests(
        userId,
      );

      if (mounted) {
        setState(() {
          _requestList = requests.map((req) {
            return {
              'request': req, // Object chính
              'id': req.id,
              'employeeName': req.requesterName.isNotEmpty
                  ? req.requesterName
                  : 'Unknown',
              'employeeId': req.requesterId,
              'dept': req.requesterDept.isNotEmpty ? req.requesterDept : 'N/A',
              'avatar': req.requesterAvatar,
              'timeInfo': req.duration,
              'processedDate': '', // Có thể format createdAt nếu cần
            };
          }).toList();

          _isLoading = false;
        });
      }
    } catch (e) {
      print("--> [LỖI] Fetch requests: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ... (Phần UI và BottomNav giữ nguyên) ...
  // Chỉ lưu ý phần gọi ManagerRequestReviewPage bên dưới:

  @override
  Widget build(BuildContext context) {
    // Filter client-side
    final displayList = _requestList.where((item) {
      final req = item['request'] as RequestModel;
      if (_isToReviewTab) {
        return req.status == RequestStatus.PENDING;
      } else {
        return req.status != RequestStatus.PENDING;
      }
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      // ... (BottomNavigationBar giữ nguyên)
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
                  child: _buildTabs(displayList.length),
                ),
                // ... (Phần Search & Filter giữ nguyên) ...
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

                // LIST VIEW
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
                              onTap: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        ManagerRequestReviewPage(
                                          // [QUAN TRỌNG] Chỉ truyền request model
                                          request: item['request'],
                                        ),
                                  ),
                                );

                                if (result == true) {
                                  _fetchRequests();
                                }
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

  // ... (Các Widget con _buildHeader, _buildTabs... giữ nguyên)
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

  Widget _buildTabs(int count) {
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
              'To review ($count)',
              _isToReviewTab,
              () => setState(() => _isToReviewTab = true),
            ),
          ),
          Expanded(
            child: _buildTabItem(
              'History',
              !_isToReviewTab,
              () => setState(() => _isToReviewTab = false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem(String title, bool isActive, VoidCallback onTap) {
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
        child: Text(
          title,
          style: TextStyle(
            color: isActive ? const Color(0xE52260FF) : const Color(0xFFB2AEAE),
            fontSize: 20,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
          ),
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

// Widget Card (Giữ nguyên, chỉ cần đảm bảo dùng data['request'].status để lấy màu)
class _ManagerRequestCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  const _ManagerRequestCard({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final RequestModel request =
        data['request']; // [QUAN TRỌNG] Lấy request mới nhất
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
                ClipOval(
                  child: Image.network(
                    data['avatar'],
                    width: 46,
                    height: 46,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 46,
                      height: 46,
                      color: Colors.grey[200],
                      child: const Icon(Icons.person, color: Colors.grey),
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

                          // [QUAN TRỌNG] Badge hiển thị trạng thái realtime từ request.status
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
