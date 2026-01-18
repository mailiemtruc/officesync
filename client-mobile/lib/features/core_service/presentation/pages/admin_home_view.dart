import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart'; // 1. Import thư viện biểu đồ
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'dart:async';
import '../../../../core/config/app_colors.dart';

import '../../../../core/api/api_client.dart';
import '../../data/models/company_model.dart';
import '../../../../core/utils/custom_snackbar.dart';
import 'company_detail_screen.dart';
import 'all_companies_screen.dart';
import 'package:officesync/features/notification_service/presentation/pages/notification_list_screen.dart';

class AdminHomeView extends StatefulWidget {
  final int currentUserId;
  const AdminHomeView({super.key, required this.currentUserId});

  @override
  State<AdminHomeView> createState() => _AdminHomeViewState();
}

class _AdminHomeViewState extends State<AdminHomeView> {
  bool _animate = false;

  bool _isLoading = true;
  Map<String, dynamic>? _stats;
  List<CompanyModel> _companies = [];

  // 2. Biến chứa dữ liệu biểu đồ
  List<FlSpot> _chartSpots = [];

  @override
  void initState() {
    super.initState();

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => _animate = true);
    });

    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final client = ApiClient();

      final results = await Future.wait([
        client.get('/admin/stats'),
        client.get('/admin/companies/top'),
      ]);

      if (mounted) {
        final statsData = results[0].data;

        // 3. Xử lý dữ liệu biểu đồ từ API (Giống hệt AnalyticsScreen)
        List<FlSpot> tempSpots = [];
        if (statsData != null &&
            statsData['history'] != null &&
            statsData['history'] is List) {
          final List<dynamic> historyList = statsData['history'];
          for (int i = 0; i < historyList.length; i++) {
            tempSpots.add(
              FlSpot(i.toDouble(), (historyList[i] as num).toDouble()),
            );
          }
          // Xử lý trường hợp chỉ có 1 điểm dữ liệu
          if (tempSpots.length == 1) {
            tempSpots.insert(0, const FlSpot(0, 0));
            tempSpots[1] = FlSpot(1, tempSpots[1].y);
          }
        }
        // Nếu không có dữ liệu thì mặc định
        if (tempSpots.isEmpty)
          tempSpots = [const FlSpot(0, 0), const FlSpot(1, 0)];

        setState(() {
          _stats = statsData;
          _chartSpots = tempSpots; // Lưu vào biến state
          _companies = (results[1].data as List)
              .map((e) => CompanyModel.fromJson(e))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching admin data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ... (Giữ nguyên hàm _toggleCompanyStatus)
  Future<void> _toggleCompanyStatus(int id, String currentStatus) async {
    try {
      final newStatus = currentStatus == 'ACTIVE' ? 'LOCKED' : 'ACTIVE';
      final client = ApiClient();
      await client.put(
        '/admin/companies/$id/status',
        data: {"status": newStatus},
      );
      _fetchData();
      if (mounted) {
        Navigator.pop(context);
        CustomSnackBar.show(
          context,
          title: "Success",
          message: "Company status updated successfully!",
          isError: false,
        );
      }
    } catch (e) {
      CustomSnackBar.show(
        context,
        title: "Action Failed",
        message: e.toString(),
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 900;

    return Container(
      color: const Color(0xFFF3F5F9),
      child: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
    );
  }

  Widget _buildMobileLayout() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAnimatedItem(0, _buildHeader()),
          const SizedBox(height: 30),

          // 4. Thay _buildBlueCard() bằng _buildChartCard()
          _buildAnimatedItem(1, _buildChartCard()),

          const SizedBox(height: 30),
          _buildAnimatedItem(2, _buildQuickActions()),
          const SizedBox(height: 35),
          _buildAnimatedItem(3, _buildListHeader()),
          const SizedBox(height: 15),
          _buildAnimatedItem(4, _buildCompanyList()),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(40.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAnimatedItem(0, _buildHeader()),
                const SizedBox(height: 40),
                _buildAnimatedItem(1, _buildChartCard()), // Thay thế ở đây
                const SizedBox(height: 40),
                _buildAnimatedItem(2, _buildQuickActions()),
              ],
            ),
          ),
          const SizedBox(width: 40),
          Expanded(
            flex: 6,
            child: Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAnimatedItem(3, _buildListHeader()),
                  const SizedBox(height: 20),
                  _buildAnimatedItem(4, _buildCompanyList()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET BIỂU ĐỒ MỚI ---
  Widget _buildChartCard() {
    return Container(
      height: 320, // Chiều cao cố định cho card biểu đồ
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "User Growth",
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${_stats?['users'] ?? 0} Users",
                    style: const TextStyle(
                      color: Color(0xFF1E293B),
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  PhosphorIconsBold.chartLineUp,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: LineChart(
              LineChartData(
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    tooltipBgColor: Colors.blueGrey,
                    getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                      return touchedBarSpots.map((barSpot) {
                        return LineTooltipItem(
                          barSpot.y.toInt().toString(),
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 5,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (value, meta) => Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          "D${value.toInt() + 1}",
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: _chartSpots,
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.primary.withOpacity(0.15),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- CÁC WIDGET CŨ (Header, QuickAction, List) ---

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 55,
              height: 55,
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.admin_panel_settings,
                color: Colors.white,
                size: 30,
              ),
            ),
            const SizedBox(width: 15),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Hi, Nguyen Van D',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 18,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'System Administrator',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 14,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        Row(
          children: [
            _buildCircleIcon(PhosphorIconsBold.bell, () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      NotificationListScreen(userId: widget.currentUserId),
                ),
              );
            }),
            const SizedBox(width: 12),
            _buildCircleIcon(PhosphorIconsBold.gear, () {}),
          ],
        ),
      ],
    );
  }

  // (Đã xóa hàm _buildBlueCard vì không dùng nữa)

  Widget _buildQuickActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildActionItem("Add Company", PhosphorIconsBold.buildings, () {}),
        _buildActionItem("Admins", PhosphorIconsBold.users, () {}),
        _buildActionItem("Reports", PhosphorIconsBold.chartBar, () {}),
        _buildActionItem("Audit Logs", PhosphorIconsBold.shieldCheck, () {}),
      ],
    );
  }

  Widget _buildListHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Top Companies',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 24,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AllCompaniesScreen(),
              ),
            ).then((_) => _fetchData());
          },
          child: const Text(
            "View all",
            style: TextStyle(
              color: Color(0xFF2260FF),
              fontSize: 13,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompanyList() {
    if (_companies.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: Text("No companies found.")),
      );
    }
    return Column(
      children: _companies.map((company) {
        final isLocked = company.status == 'LOCKED';
        final statusColor = isLocked
            ? const Color(0xFFDC2626)
            : const Color(0xFF4DE275);
        final displayDomain = "${company.domain}.officesync.com";

        return Column(
          children: [
            _buildCompanyItem(
              name: company.name,
              status: company.status,
              statusColor: statusColor,
              domain: displayDomain,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CompanyDetailScreen(
                      companyId: company.id,
                      companyName: company.name,
                    ),
                  ),
                ).then((_) {
                  _fetchData();
                });
              },
            ),
            const SizedBox(height: 16),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildActionItem(String label, IconData icon, VoidCallback onTap) {
    return Column(
      children: [
        Material(
          color: const Color(0xFFE0E7FF),
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: 68,
              height: 68,
              alignment: Alignment.center,
              child: Icon(icon, color: const Color(0xFF1E293B), size: 30),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: 75,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompanyItem({
    required String name,
    required String status,
    required Color statusColor,
    required String domain,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          color: Color(0xFF1E293B),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Icon(PhosphorIconsBold.dotsThree, color: Colors.grey),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      domain,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCircleIcon(IconData icon, VoidCallback onTap) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Center(
            child: Icon(icon, size: 24, color: const Color(0xFF1E293B)),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedItem(int index, Widget child) {
    return AnimatedSlide(
      offset: _animate ? Offset.zero : const Offset(0, 0.1),
      duration: Duration(milliseconds: 500 + (index * 100)),
      curve: Curves.easeOutQuad,
      child: AnimatedOpacity(
        opacity: _animate ? 1.0 : 0.0,
        duration: Duration(milliseconds: 500 + (index * 100)),
        child: child,
      ),
    );
  }
}
