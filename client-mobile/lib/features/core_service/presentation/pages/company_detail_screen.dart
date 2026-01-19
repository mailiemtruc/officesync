import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/config/app_colors.dart';
import '../../../../core/api/api_client.dart';
import '../../data/models/company_model.dart';
import '../../data/models/user_model.dart';
import '../../../../core/utils/custom_snackbar.dart';

class CompanyDetailScreen extends StatefulWidget {
  final int companyId;
  final String companyName;

  const CompanyDetailScreen({
    super.key,
    required this.companyId,
    required this.companyName,
  });

  @override
  State<CompanyDetailScreen> createState() => _CompanyDetailScreenState();
}

class _CompanyDetailScreenState extends State<CompanyDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  CompanyModel? _company;
  List<UserModel> _users = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    try {
      final client = ApiClient();
      final results = await Future.wait([
        client.get('/admin/companies/${widget.companyId}'),
        client.get('/admin/companies/${widget.companyId}/users'),
      ]);

      if (mounted) {
        setState(() {
          _company = CompanyModel.fromJson(results[0].data);
          _users = (results[1].data as List)
              .map((e) => UserModel.fromJson(e))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching detail: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleUserStatus(int userId, String currentStatus) async {
    try {
      final newStatus = currentStatus == 'ACTIVE' ? 'LOCKED' : 'ACTIVE';
      final client = ApiClient();

      await client.put(
        '/admin/users/$userId/status',
        data: {"status": newStatus},
      );

      if (mounted) {
        Navigator.pop(context);
        _fetchDetail();

        CustomSnackBar.show(
          context,
          title: "Success",
          message:
              "User account has been ${newStatus.toLowerCase()} successfully.",
          isError: false,
        );
      }
    } catch (e) {
      print("Error: $e");
      if (mounted) {
        Navigator.pop(context);
        CustomSnackBar.show(
          context,
          title: "Action Failed",
          message: "Could not update user status. Please try again.",
          isError: true,
        );
      }
    }
  }

  void _showUserAction(UserModel user) {
    final isLocked = user.status == 'LOCKED';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Action for ${user.fullName}",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () => _toggleUserStatus(user.id, user.status),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isLocked ? Colors.green : Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: Icon(
                    isLocked
                        ? PhosphorIconsBold.lockOpen
                        : PhosphorIconsBold.lock,
                  ),
                  label: Text(isLocked ? "Unlock Account" : "Lock Account"),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "Cancel",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9), // Màu nền tổng thể sáng sủa
      // --- HEADER (GIỮ NGUYÊN NHƯ YÊU CẦU) ---
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF2260FF)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.companyName.toUpperCase(),
          style: const TextStyle(
            color: Color(0xFF2260FF),
            fontWeight: FontWeight.bold,
            fontSize: 24, // 👈 Đã thêm cỡ chữ tại đây
            fontFamily: 'Inter',
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: "Overview"),
            Tab(text: "Members"),
          ],
        ),
      ),

      // --- BODY ---
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [_buildOverviewTab(), _buildMembersTab()],
            ),
    );
  }

  // --- TAB 1: OVERVIEW (NÂNG CẤP) ---
  Widget _buildOverviewTab() {
    if (_company == null) return const Center(child: Text("No info"));
    final isCompanyLocked = _company!.status == 'LOCKED';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // 1. Thẻ thông tin chính (Modern Card)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2260FF).withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                // Logo / Avatar
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                    image:
                        (_company!.logoUrl != null &&
                            _company!.logoUrl!.isNotEmpty)
                        ? DecorationImage(
                            image: NetworkImage(_company!.logoUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child:
                      (_company!.logoUrl == null || _company!.logoUrl!.isEmpty)
                      ? Center(
                          child: Text(
                            _company!.name.isNotEmpty ? _company!.name[0] : "C",
                            style: const TextStyle(
                              fontSize: 32,
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : null,
                ),

                const SizedBox(height: 16),

                // Tên công ty
                Text(
                  _company!.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                // Domain
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "${_company!.domain}.officesync.com",
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ),

                const SizedBox(height: 24),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 24),

                // Danh sách thông tin chi tiết
                _buildModernInfoRow(
                  PhosphorIconsBold.buildings,
                  "Industry",
                  _company!.industry ?? "Not specified",
                ),

                const SizedBox(height: 16),

                _buildModernInfoRow(
                  PhosphorIconsBold.users,
                  "Total Employees",
                  "${_users.length} Members",
                ),

                const SizedBox(height: 16),

                // Status Row (Custom)
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        PhosphorIconsBold.checkCircle,
                        size: 20,
                        color: Colors.grey[400],
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        "Current Status",
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    _buildModernStatusBadge(_company!.status),
                  ],
                ),

                // About Section
                if (_company!.description != null &&
                    _company!.description!.isNotEmpty) ...[
                  const SizedBox(height: 30),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "About Company",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey[800],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC), // Xám xanh rất nhạt
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.withOpacity(0.1)),
                    ),
                    child: Text(
                      _company!.description!,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        height: 1.6,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Action Button (Lock/Unlock)
          SizedBox(
            width: double.infinity,
            height: 56, // Cao hơn chút cho dễ bấm
            child: ElevatedButton.icon(
              onPressed: () async {
                // Logic xử lý lock/unlock
                String newStatus = _company!.status == 'ACTIVE'
                    ? 'LOCKED'
                    : 'ACTIVE';
                final client = ApiClient();
                try {
                  await client.put(
                    '/admin/companies/${_company!.id}/status',
                    data: {"status": newStatus},
                  );
                  _fetchDetail();
                  CustomSnackBar.show(
                    context,
                    title: "Success",
                    message:
                        "Company has been ${newStatus.toLowerCase()} successfully.",
                    isError: false,
                  );
                } catch (e) {
                  print("Error: $e");
                  CustomSnackBar.show(
                    context,
                    title: "Action Failed",
                    message: "Could not update company status.",
                    isError: true,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isCompanyLocked
                    ? const Color(0xFF22C55E)
                    : const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                elevation: 4,
                shadowColor: (isCompanyLocked ? Colors.green : Colors.red)
                    .withOpacity(0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: Icon(
                isCompanyLocked
                    ? PhosphorIconsBold.lockOpen
                    : PhosphorIconsBold.lock,
                size: 22,
              ),
              label: Text(
                isCompanyLocked ? "Activate Company" : "Lock Company",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // Helper cho Overview Row
  Widget _buildModernInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: Colors.grey[400]),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Helper Badge Status (Pill + Dot style)
  Widget _buildModernStatusBadge(String status) {
    final isLocked = status == 'LOCKED';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isLocked
            ? Colors.red.withOpacity(0.08)
            : Colors.green.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isLocked ? Colors.red : Colors.green,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isLocked ? "Locked" : "Active",
            style: TextStyle(
              color: isLocked ? Colors.red[700] : Colors.green[700],
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 2: MEMBERS (NÂNG CẤP) ---
  Widget _buildMembersTab() {
    final directors = _users.where((u) => u.role == 'COMPANY_ADMIN').toList();
    final managers = _users.where((u) => u.role == 'MANAGER').toList();
    final staffs = _users.where((u) => u.role == 'STAFF').toList();

    if (_users.isEmpty) return const Center(child: Text("No members found"));

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildRoleSection("Directors", directors, Colors.purple),
        _buildRoleSection("Managers", managers, Colors.orange),
        _buildRoleSection("Staff", staffs, Colors.blue),
      ],
    );
  }

  Widget _buildRoleSection(String title, List<UserModel> users, Color color) {
    if (users.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 0, 10),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
                margin: const EdgeInsets.only(right: 10),
              ),
              Text(
                "$title (${users.length})",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey[800],
                ),
              ),
            ],
          ),
        ),
        ...users.map((user) => _buildModernUserItem(user)).toList(),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildModernUserItem(UserModel user) {
    final isLocked = user.status == 'LOCKED';

    return Container(
      margin: const EdgeInsets.only(
        bottom: 12,
      ), // Tăng khoảng cách giữa các item
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        // Shadow nhẹ, clean hơn
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2260FF).withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isLocked ? Colors.red.withOpacity(0.2) : Colors.transparent,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          // Bấm vào item để mở menu hành động (tùy chọn)
          onTap: () => _showUserAction(user),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isLocked
                        ? Colors.red.withOpacity(0.1)
                        : AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      user.fullName.isNotEmpty
                          ? user.fullName[0].toUpperCase()
                          : "U",
                      style: TextStyle(
                        color: isLocked ? Colors.red : AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fullName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: isLocked ? Colors.grey : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user.email,
                        style: TextStyle(color: Colors.grey[500], fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Status Badge & Action Icon
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildModernStatusBadge(user.status),
                    // Icon dots nhỏ nếu cần, hoặc để trống vì đã có onTap
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
