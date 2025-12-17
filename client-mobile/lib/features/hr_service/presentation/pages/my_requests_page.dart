import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/config/app_colors.dart';
import '../../data/models/request_model.dart';
import 'create_request_page.dart';
import 'request_detail_page.dart';

class MyRequestsPage extends StatefulWidget {
  const MyRequestsPage({super.key});

  @override
  State<MyRequestsPage> createState() => _MyRequestsPageState();
}

class _MyRequestsPageState extends State<MyRequestsPage> {
  String _selectedFilter = 'All';

  // Dữ liệu mẫu
  final List<RequestModel> _requests = [
    RequestModel(
      id: '1',
      type: RequestType.leave,
      title: 'Annual Leave',
      description: 'Taking a few days off for family trip to Da Nang city.',
      dateRange: 'Oct 24 - Oct 26',
      duration: '3 days',
      status: RequestStatus.pending,
    ),
    RequestModel(
      id: '2',
      type: RequestType.overtime,
      title: 'Overtime',
      description: 'Urgent release deployment for Project X.',
      dateRange: 'Oct 20 • 18:00 - 21:00',
      duration: '3 hours',
      status: RequestStatus.approved,
    ),
    RequestModel(
      id: '3',
      type: RequestType.lateEarly,
      title: 'Late Arrival',
      description: 'Heavy rain caused traffic jam.',
      dateRange: 'Sep 15 • 08:30 - 09:30',
      duration: '1 hour',
      status: RequestStatus.rejected,
    ),
  ];

  List<RequestModel> get _filteredRequests {
    if (_selectedFilter == 'All') return _requests;
    return _requests.where((r) => r.statusText == _selectedFilter).toList();
  }

  // --- HÀM XỬ LÝ ĐIỀU HƯỚNG ---
  void _onBottomNavTap(int index) {
    switch (index) {
      case 0: // Home -> Về Dashboard
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/dashboard',
          (route) => false,
        );
        break;
      case 1: // Menu -> Quay lại Menu (Pop)
        Navigator.pop(context);
        break;
      case 2: // Profile
        Navigator.pushNamed(context, '/user_profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),

      // --- THANH ĐIỀU HƯỚNG ---
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
          currentIndex: 1, // Đang ở nhánh Menu
          onTap: _onBottomNavTap,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
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

      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateRequestPage()),
          );
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
                      'THIS MONTH',
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
                  child: ListView.builder(
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
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RequestDetailPage(request: request),
              ),
            );
          },
          splashColor: Colors.grey.withOpacity(0.1),
          highlightColor: Colors.grey.withOpacity(0.05),
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
