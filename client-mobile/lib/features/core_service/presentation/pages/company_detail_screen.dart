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

  // 🔴 1. HÀM GỌI API KHÓA/MỞ KHÓA USER
  // Tìm hàm này và sửa nội dung bên trong
  Future<void> _toggleUserStatus(int userId, String currentStatus) async {
    try {
      final newStatus = currentStatus == 'ACTIVE' ? 'LOCKED' : 'ACTIVE';
      final client = ApiClient();

      await client.put(
        '/admin/users/$userId/status',
        data: {"status": newStatus},
      );

      if (mounted) {
        Navigator.pop(context); // Đóng BottomSheet
        _fetchDetail(); // Reload lại danh sách

        // ✅ SỬA: Gọi CustomSnackBar dùng chung
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

        // ✅ SỬA: Gọi CustomSnackBar dùng chung
        CustomSnackBar.show(
          context,
          title: "Action Failed",
          message: "Could not update user status. Please try again.",
          isError: true,
        );
      }
    }
  }

  // 🔴 2. HÀM HIỂN THỊ MENU HÀNH ĐỘNG
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

              // Nút Lock/Unlock
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

              // Nút Hủy
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
      backgroundColor: const Color(0xFFF3F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.companyName,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [_buildOverviewTab(), _buildMembersTab()],
            ),
    );
  }

  // --- TAB 1: Giữ nguyên ---
  Widget _buildOverviewTab() {
    if (_company == null) return const Center(child: Text("No info"));
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: Text(
                    _company!.name.isNotEmpty ? _company!.name[0] : "C",
                    style: const TextStyle(
                      fontSize: 40,
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _buildInfoRow(
                  PhosphorIconsBold.globe,
                  "Domain",
                  "${_company!.domain}.officesync.com",
                ),
                const Divider(),
                _buildInfoRow(
                  PhosphorIconsBold.checkCircle,
                  "Status",
                  _company!.status,
                  isStatus: true,
                  color: _company!.status == 'ACTIVE'
                      ? Colors.green
                      : Colors.red,
                ),
                const Divider(),
                _buildInfoRow(
                  PhosphorIconsBold.users,
                  "Total Employees",
                  "${_users.length}",
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Nút Khóa Công ty
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () async {
                String newStatus = _company!.status == 'ACTIVE'
                    ? 'LOCKED'
                    : 'ACTIVE';
                final client = ApiClient();

                try {
                  await client.put(
                    '/admin/companies/${_company!.id}/status',
                    data: {"status": newStatus},
                  );

                  _fetchDetail(); // Reload UI

                  // ✅ SỬA: Gọi CustomSnackBar dùng chung
                  CustomSnackBar.show(
                    context,
                    title: "Success",
                    message:
                        "Company has been ${newStatus.toLowerCase()} successfully.",
                    isError: false,
                  );
                } catch (e) {
                  print("Error: $e");

                  // ✅ SỬA: Gọi CustomSnackBar dùng chung
                  CustomSnackBar.show(
                    context,
                    title: "Action Failed",
                    message: "Could not update company status.",
                    isError: true,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _company!.status == 'ACTIVE'
                    ? Colors.red.withOpacity(0.1)
                    : Colors.green.withOpacity(0.1),
                elevation: 0,
                foregroundColor: _company!.status == 'ACTIVE'
                    ? Colors.red
                    : Colors.green,
              ),
              icon: Icon(
                _company!.status == 'ACTIVE'
                    ? PhosphorIconsBold.lock
                    : PhosphorIconsBold.lockOpen,
              ),
              label: Text(
                _company!.status == 'ACTIVE'
                    ? "Lock Company"
                    : "Activate Company",
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    bool isStatus = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 15),
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          isStatus
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color!.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    value,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                )
              : Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ],
      ),
    );
  }

  // --- TAB 2: MEMBERS ---
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
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 16,
                color: color,
                margin: const EdgeInsets.only(right: 8),
              ),
              Text(
                "$title (${users.length})",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        ...users
            .map((user) => _buildUserItem(user))
            .toList(), // Cập nhật cách gọi map
        const SizedBox(height: 10),
      ],
    );
  }

  // 🔴 3. SỬA GIAO DIỆN ITEM USER
  Widget _buildUserItem(UserModel user) {
    // 1. Kiểm tra logic trạng thái
    final isLocked = user.status == 'LOCKED';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        // Nếu bị khóa thì viền đỏ nhẹ để gây chú ý
        border: isLocked
            ? Border.all(color: Colors.red.withOpacity(0.3))
            : null,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: isLocked ? Colors.grey[200] : AppColors.inputFill,
          child: isLocked
              ? const Icon(
                  Icons.lock,
                  size: 20,
                  color: Colors.grey,
                ) // Hiện icon khóa nếu bị lock
              : Text(
                  user.fullName.isNotEmpty
                      ? user.fullName[0].toUpperCase()
                      : "U",
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
        title: Row(
          children: [
            // Tên người dùng
            Flexible(
              child: Text(
                user.fullName,
                overflow: TextOverflow.ellipsis, // Cắt bớt nếu tên quá dài
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isLocked ? Colors.grey : Colors.black,
                ),
              ),
            ),
            const SizedBox(width: 8),

            // 🔴 PHẦN MỚI: Badge hiển thị trạng thái (ACTIVE/LOCKED)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isLocked
                    ? const Color(0xFFFEE2E2) // Đỏ nhạt
                    : const Color(0xFFDCFCE7), // Xanh nhạt
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                user.status, // Hiển thị text từ API
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isLocked
                      ? const Color(0xFFDC2626) // Chữ đỏ
                      : const Color(0xFF16A34A), // Chữ xanh
                ),
              ),
            ),
          ],
        ),
        subtitle: Text(
          user.email,
          style: TextStyle(color: isLocked ? Colors.grey : null),
        ),
        trailing: IconButton(
          icon: Icon(PhosphorIconsBold.dotsThree, color: Colors.grey),
          onPressed: () => _showUserAction(user), // Gọi menu khóa/mở khóa
        ),
      ),
    );
  }
}
