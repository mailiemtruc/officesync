import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/config/app_colors.dart';
import '../../../../core/api/api_client.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool _isLoading = true;
  int _totalUsers = 0;
  int _totalCompanies = 0;

  // Danh sách điểm biểu đồ
  List<FlSpot> _chartSpots = [];

  @override
  void initState() {
    super.initState();
    _fetchRealStats();
  }

  Future<void> _fetchRealStats() async {
    try {
      final client = ApiClient();
      final response = await client.get('/admin/stats');

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;

        // 1. Parse dữ liệu lịch sử từ Server
        List<FlSpot> tempSpots = [];

        if (data['history'] != null && data['history'] is List) {
          final List<dynamic> historyList = data['history'];

          if (historyList.isNotEmpty) {
            for (int i = 0; i < historyList.length; i++) {
              final double yVal = (historyList[i] as num).toDouble();
              tempSpots.add(FlSpot(i.toDouble(), yVal));
            }

            // Nếu chỉ có 1 điểm, thêm điểm 0 vào trước
            if (tempSpots.length == 1) {
              FlSpot current = tempSpots[0];
              tempSpots.clear();
              tempSpots.add(const FlSpot(0, 0));
              tempSpots.add(FlSpot(1, current.y));
            }
          }
        }

        if (tempSpots.isEmpty) {
          tempSpots.add(const FlSpot(0, 0));
          tempSpots.add(const FlSpot(1, 0));
        }

        if (mounted) {
          setState(() {
            _totalUsers = data['users'] ?? 0;
            _totalCompanies = data['companies'] ?? 0;
            _chartSpots = tempSpots;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print("Error fetching analytics: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      appBar: AppBar(
        title: const Text(
          "System Analytics",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primary),
            onPressed: () {
              setState(() => _isLoading = true);
              _fetchRealStats();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Thẻ tổng quan
                  Row(
                    children: [
                      _buildStatCard(
                        "Total Users",
                        "$_totalUsers",
                        Colors.blue,
                      ),
                      const SizedBox(width: 15),
                      _buildStatCard(
                        "Companies",
                        "$_totalCompanies",
                        Colors.orange,
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // 2. Tiêu đề biểu đồ
                  const Text(
                    "User Growth History (Last 7 Days)",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 15),

                  // 3. Khung Biểu đồ
                  Container(
                    height: 300,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: LineChart(
                      LineChartData(
                        // 👇 [ĐÃ SỬA] Dùng tooltipBgColor cho phiên bản cũ
                        lineTouchData: LineTouchData(
                          touchTooltipData: LineTouchTooltipData(
                            tooltipBgColor:
                                Colors.blueGrey, // <--- SỬA DÒNG NÀY
                            getTooltipItems:
                                (List<LineBarSpot> touchedBarSpots) {
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
                        // Cấu hình trục X, Y
                        titlesData: FlTitlesData(
                          show: true,
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),

                          // Trục trái (Số lượng)
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: 5,
                              reservedSize: 35,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  value.toInt().toString(),
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              },
                            ),
                          ),

                          // Trục dưới (Ngày)
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: 1,
                              reservedSize: 30,
                              getTitlesWidget: (value, meta) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    "D${value.toInt() + 1}",
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              },
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
                              color: AppColors.primary.withOpacity(0.2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
