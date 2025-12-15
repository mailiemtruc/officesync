import 'package:flutter/material.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/config/app_colors.dart';
import '../../data/models/company_model.dart';
import 'company_detail_screen.dart';

class AllCompaniesScreen extends StatefulWidget {
  const AllCompaniesScreen({super.key});

  @override
  State<AllCompaniesScreen> createState() => _AllCompaniesScreenState();
}

class _AllCompaniesScreenState extends State<AllCompaniesScreen> {
  List<CompanyModel> _companies = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAllCompanies();
  }

  Future<void> _fetchAllCompanies() async {
    try {
      final client = ApiClient();
      // Gọi API lấy TẤT CẢ công ty
      final response = await client.get('/admin/companies');
      if (mounted) {
        setState(() {
          _companies = (response.data as List)
              .map((e) => CompanyModel.fromJson(e))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      print("Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "All Companies",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: _companies.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final company = _companies[index];
                final isLocked = company.status == 'LOCKED';

                return _buildCompanyItem(company, isLocked);
              },
            ),
    );
  }

  Widget _buildCompanyItem(CompanyModel company, bool isLocked) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 10,
        ),
        title: Text(
          company.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text("${company.domain}.officesync.com"),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isLocked ? Colors.red[50] : Colors.green[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            company.status,
            style: TextStyle(
              color: isLocked ? Colors.red : Colors.green,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        onTap: () {
          // Chuyển sang chi tiết và reload list khi quay lại
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CompanyDetailScreen(
                companyId: company.id,
                companyName: company.name,
              ),
            ),
          ).then((_) => _fetchAllCompanies());
        },
      ),
    );
  }
}
