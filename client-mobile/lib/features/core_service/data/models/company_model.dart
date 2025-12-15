// lib/features/core_service/data/models/company_model.dart

class CompanyModel {
  final int id;
  final String name;
  final String domain;
  final String status;
  // 🔴 Thêm các trường mới (có thể null)
  final String? logoUrl;
  final String? industry;
  final String? description;

  CompanyModel({
    required this.id,
    required this.name,
    required this.domain,
    required this.status,
    this.logoUrl,
    this.industry,
    this.description,
  });

  factory CompanyModel.fromJson(Map<String, dynamic> json) {
    return CompanyModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'Unnamed',
      domain: json['domain'] ?? '',
      status: json['status'] ?? 'ACTIVE',
      // 🔴 Map dữ liệu mới
      logoUrl: json['logoUrl'],
      industry: json['industry'],
      description: json['description'],
    );
  }
}
