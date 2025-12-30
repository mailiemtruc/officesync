import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// [MỚI] Thêm thư viện Socket
import 'package:stomp_dart_client/stomp.dart';
import 'package:stomp_dart_client/stomp_config.dart';
import 'package:stomp_dart_client/stomp_frame.dart';

import '../../../../core/config/app_colors.dart';
import '../../data/models/request_model.dart';
import '../../data/datasources/request_remote_data_source.dart';
import '../../domain/repositories/request_repository_impl.dart';

import 'create_request_page.dart';
import 'request_detail_page.dart';

class MyRequestsPage extends StatefulWidget {
  const MyRequestsPage({super.key});

  @override
  State<MyRequestsPage> createState() => _MyRequestsPageState();
}

class _MyRequestsPageState extends State<MyRequestsPage> {
  String _selectedFilter = 'All';
  List<RequestModel> _requests = [];
  bool _isLoading = true;

  final _storage = const FlutterSecureStorage();
  late final RequestRepositoryImpl _repository;

  // [MỚI] Biến Socket
  StompClient? _stompClient;

  @override
  void initState() {
    super.initState();
    _repository = RequestRepositoryImpl(
      remoteDataSource: RequestRemoteDataSource(),
    );
    _fetchRequests();
  }

  // [MỚI] Ngắt kết nối khi thoát
  @override
  void dispose() {
    _stompClient?.deactivate();
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

  // [MỚI] Hàm khởi tạo WebSocket
  void _initWebSocket(String userId) {
    // Nếu đã connect rồi thì thôi
    if (_stompClient != null && _stompClient!.isActive) return;

    final socketUrl = 'ws://10.0.2.2:8081/ws-hr/websocket';

    _stompClient = StompClient(
      config: StompConfig(
        url: socketUrl,
        onConnect: (StompFrame frame) {
          print("--> [MyRequests] Connected to WS");
          // Subscribe kênh riêng của User để nhận tin: Tạo mới, Duyệt, Từ chối
          _stompClient!.subscribe(
            destination: '/topic/user/$userId/requests',
            callback: (StompFrame frame) {
              if (frame.body != null) {
                print("--> [MyRequests] Update received: ${frame.body}");
                final dynamic data = jsonDecode(frame.body!);
                final updatedReq = RequestModel.fromJson(data);

                if (mounted) {
                  setState(() {
                    final index = _requests.indexWhere(
                      (r) => r.id == updatedReq.id,
                    );
                    if (index != -1) {
                      // Cập nhật đơn đã có
                      _requests[index] = updatedReq;
                    } else {
                      // Thêm đơn mới vào đầu list
                      _requests.insert(0, updatedReq);
                    }
                  });
                }
              }
            },
          );
        },
        onWebSocketError: (dynamic error) => print("--> [WS Error]: $error"),
      ),
    );
    _stompClient!.activate();
  }

  Future<void> _fetchRequests() async {
    setState(() => _isLoading = true);
    try {
      final userId = await _getUserIdFromStorage();
      if (userId != null) {
        // [MỚI] Kích hoạt Socket ngay khi có ID
        _initWebSocket(userId);

        final data = await _repository.getMyRequests(userId);
        setState(() {
          _requests = data;
          _requests.sort((a, b) => b.startTime.compareTo(a.startTime));
        });
      } else {
        print("User ID not found!");
      }
    } catch (e) {
      print("Error fetching requests: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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

                const SizedBox(height: 20),
                // Filter Tabs
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

                // List Requests
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _filteredRequests.isEmpty
                      ? Center(
                          child: Text(
                            "No requests found",
                            style: TextStyle(color: Colors.grey[400]),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 8,
                          ),
                          itemCount: _filteredRequests.length,
                          itemBuilder: (context, index) {
                            return _buildRequestCard(_filteredRequests[index]);
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

  Widget _buildSearchBar() => Container(
    height: 45,
    decoration: BoxDecoration(
      color: const Color(0xFFF5F5F5),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE0E0E0)),
    ),
    child: TextField(
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
}
