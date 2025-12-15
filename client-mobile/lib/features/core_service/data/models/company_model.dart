class CompanyModel {
  final int id;
  final String name;
  final String domain;
  final String status;

  CompanyModel({
    required this.id,
    required this.name,
    required this.domain,
    required this.status,
  });

  factory CompanyModel.fromJson(Map<String, dynamic> json) {
    return CompanyModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      domain: json['domain'] ?? '',
      status: json['status'] ?? 'ACTIVE',
    );
  }
}
