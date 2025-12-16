class CompanyModel {
  final int id;
  final String name;
  final String domain;
  final String status;

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

      logoUrl: json['logoUrl'],
      industry: json['industry'],
      description: json['description'],
    );
  }
}
