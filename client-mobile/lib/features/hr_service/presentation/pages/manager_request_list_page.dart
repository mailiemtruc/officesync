import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/config/app_colors.dart';
import '../../data/models/request_model.dart';
import 'manager_request_review_page.dart';

class ManagerRequestListPage extends StatefulWidget {
  const ManagerRequestListPage({super.key});

  @override
  State<ManagerRequestListPage> createState() => _ManagerRequestListPageState();
}

class _ManagerRequestListPageState extends State<ManagerRequestListPage> {
  bool _isToReviewTab = true;

  // --- DỮ LIỆU MẪU (MOCK DATA) ---
  final List<Map<String, dynamic>> _toReviewList = [
    {
      'employeeName': 'Nguyen Van A',
      'employeeId': '001',
      'dept': 'Business',
      'avatar': 'https://i.pravatar.cc/150?img=11',
      'request': RequestModel(
        id: '2025-090',
        type: RequestType.overtime,
        title: 'Overtime',
        description: 'Deadline.',
        dateRange: 'Oct 20, 2025',
        duration: '3 hours',
        status: RequestStatus.pending,
      ),
      'timeInfo': '18:00 - 21:00',
    },
    {
      'employeeName': 'Tran Thi B',
      'employeeId': '002',
      'dept': 'Human resources',
      'avatar': 'https://i.pravatar.cc/150?img=5',
      'request': RequestModel(
        id: '2025-089',
        type: RequestType.leave,
        title: 'Annual Leave',
        description: 'Family trip.',
        dateRange: 'Oct 20, 2025',
        duration: '3 Days',
        status: RequestStatus.pending,
      ),
      'timeInfo': '3 Days',
    },
    {
      'employeeName': 'Nguyen Van E',
      'employeeId': '004',
      'dept': 'Human resources',
      'avatar': 'https://i.pravatar.cc/150?img=8',
      'request': RequestModel(
        id: '2025-091',
        type: RequestType.lateEarly,
        title: 'Late Arrival',
        description: 'Traffic jam.',
        dateRange: 'Oct 21',
        duration: '1 Hour',
        status: RequestStatus.pending,
      ),
      'timeInfo': '1 Hour',
    },
  ];

  final List<Map<String, dynamic>> _historyList = [
    {
      'employeeName': 'Nguyen Van K',
      'employeeId': '061',
      'dept': 'Human resources',
      'avatar': 'https://i.pravatar.cc/150?img=3',
      'request': RequestModel(
        id: '2025-001',
        type: RequestType.lateEarly,
        title: 'Late Arrival',
        description: 'Overslept.',
        dateRange: 'Oct 18, 2025',
        duration: '2 Hour',
        status: RequestStatus.rejected,
      ),
      'processedDate': 'Processed on Oct 18',
    },
    {
      'employeeName': 'Tran Thi B',
      'employeeId': '002',
      'dept': 'Human resources',
      'avatar': 'https://i.pravatar.cc/150?img=5',
      'request': RequestModel(
        id: '2025-003',
        type: RequestType.leave,
        title: 'Annual Leave',
        description: 'Sick.',
        dateRange: 'Oct 17, 2025',
        duration: '3 Days',
        status: RequestStatus.rejected,
      ),
      'processedDate': 'Processed on Oct 17',
    },
    {
      'employeeName': 'Nguyen Van A',
      'employeeId': '001',
      'dept': 'Business',
      'avatar': 'https://i.pravatar.cc/150?img=11',
      'request': RequestModel(
        id: '2025-002',
        type: RequestType.overtime,
        title: 'Overtime',
        description: 'System fix.',
        dateRange: 'Oct 20, 2025',
        duration: '3 hours',
        status: RequestStatus.approved,
      ),
      'processedDate': 'Processed on Oct 20',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final displayList = _isToReviewTab ? _toReviewList : _historyList;

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

                // Tabs
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _buildTabs(),
                ),

                const SizedBox(height: 24),

                // Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Expanded(child: _buildSearchBar()),
                      const SizedBox(width: 12),
                      _buildFilterButton(), // Đã sửa lỗi bấm được
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Section Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _isToReviewTab ? 'TODAY' : 'SEPTEMBER 2025',
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

                // List
                Expanded(
                  child: ListView.builder(
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
                              builder: (context) => ManagerRequestReviewPage(
                                request: item['request'],
                                employeeName: item['employeeName'],
                                employeeId: item['employeeId'],
                                employeeDept: item['dept'],
                                employeeAvatar: item['avatar'],
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

  Widget _buildTabs() {
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
              'To review (${_toReviewList.length})',
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

  // --- NÚT LỌC ĐÃ SỬA: Bấm được ---
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
          onTap: () {
            // Sự kiện bấm nút lọc
          },
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
                // 1. Avatar
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
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // 2. Nội dung chính
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Hàng 1: [Tên + Manager Tag (Flow)] ---- [Badge Status]
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment
                            .start, // Căn trên để nếu tên xuống dòng thì badge vẫn ở trên
                        children: [
                          // Cụm Tên và Tag Manager (Sử dụng Text.rich để wrap dòng mượt mà)
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
                                    const TextSpan(text: ' '), // Khoảng cách
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
                              // Cho phép xuống hàng không giới hạn hoặc giới hạn 2 dòng tùy bạn
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                          // Badge Status
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
                              request.statusText,
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

                      // Hàng 2: ID | Dept
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

                      // Hàng 3: Loại đơn + Thời gian
                      RichText(
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: request.title,
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

  // --- MÃ MÀU ---
  Color _getExactStatusBgColor(RequestStatus status) {
    switch (status) {
      case RequestStatus.pending:
        return const Color(0xFFFFF7ED);
      case RequestStatus.rejected:
        return const Color(0xFFFEF2F2);
      case RequestStatus.approved:
        return const Color(0xFFF0FDF4);
      default:
        return const Color(0xFFF3F4F6);
    }
  }

  Color _getExactStatusColor(RequestStatus status) {
    switch (status) {
      case RequestStatus.pending:
        return const Color(0xFFEA580C);
      case RequestStatus.rejected:
        return const Color(0xFFDC2626);
      case RequestStatus.approved:
        return const Color(0xFF16A34A);
      default:
        return const Color(0xFF374151);
    }
  }
}
