class FinancialAccountModel {
  final String id;
  final String userId;
  final double balanceDue;
  final double totalPaid;
  final String? updatedAt;

  const FinancialAccountModel({
    required this.id,
    required this.userId,
    required this.balanceDue,
    required this.totalPaid,
    this.updatedAt,
  });

  factory FinancialAccountModel.fromJson(Map<String, dynamic> json) {
    return FinancialAccountModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      balanceDue: double.tryParse(json['balance_due']?.toString() ?? '0') ?? 0,
      totalPaid: double.tryParse(json['total_paid']?.toString() ?? '0') ?? 0,
      updatedAt: json['updated_at']?.toString(),
    );
  }
}
