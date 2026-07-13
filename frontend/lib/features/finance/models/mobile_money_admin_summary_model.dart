class MobileMoneyAdminSummaryModel {
  final int todayCount;
  final int pendingCount;
  final int successfulCount;
  final int failedCount;
  final int expiredCount;
  final int successfulAmount;
  final int todaySuccessfulAmount;
  final DateTime? lastReconciliationAt;
  final List<MobileMoneyAdminTransactionModel> recentTransactions;

  const MobileMoneyAdminSummaryModel({
    required this.todayCount,
    required this.pendingCount,
    required this.successfulCount,
    required this.failedCount,
    required this.expiredCount,
    required this.successfulAmount,
    required this.todaySuccessfulAmount,
    this.lastReconciliationAt,
    required this.recentTransactions,
  });

  factory MobileMoneyAdminSummaryModel.fromJson(Map<String, dynamic> json) {
    final rawRecent = json['recent_transactions'];
    return MobileMoneyAdminSummaryModel(
      todayCount: int.tryParse(json['today_count']?.toString() ?? '0') ?? 0,
      pendingCount: int.tryParse(json['pending_count']?.toString() ?? '0') ?? 0,
      successfulCount:
          int.tryParse(json['successful_count']?.toString() ?? '0') ?? 0,
      failedCount: int.tryParse(json['failed_count']?.toString() ?? '0') ?? 0,
      expiredCount: int.tryParse(json['expired_count']?.toString() ?? '0') ?? 0,
      successfulAmount:
          int.tryParse(json['successful_amount']?.toString() ?? '0') ?? 0,
      todaySuccessfulAmount:
          int.tryParse(json['today_successful_amount']?.toString() ?? '0') ?? 0,
      lastReconciliationAt: DateTime.tryParse(
        json['last_reconciliation_at']?.toString() ?? '',
      ),
      recentTransactions: rawRecent is List
          ? rawRecent
                .whereType<Map<String, dynamic>>()
                .map(MobileMoneyAdminTransactionModel.fromJson)
                .toList()
          : const [],
    );
  }
}

class MobileMoneyAdminTransactionModel {
  final String id;
  final String memberId;
  final int amount;
  final String currency;
  final String provider;
  final String? channel;
  final String status;
  final DateTime? createdAt;
  final DateTime? lastVerifiedAt;

  const MobileMoneyAdminTransactionModel({
    required this.id,
    required this.memberId,
    required this.amount,
    required this.currency,
    required this.provider,
    this.channel,
    required this.status,
    this.createdAt,
    this.lastVerifiedAt,
  });

  factory MobileMoneyAdminTransactionModel.fromJson(Map<String, dynamic> json) {
    return MobileMoneyAdminTransactionModel(
      id: json['id']?.toString() ?? '',
      memberId: json['member_id']?.toString() ?? '',
      amount: int.tryParse(json['amount']?.toString() ?? '0') ?? 0,
      currency: json['currency']?.toString() ?? 'XOF',
      provider: json['provider']?.toString() ?? '',
      channel: json['channel']?.toString(),
      status: json['status']?.toString() ?? 'pending',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      lastVerifiedAt: DateTime.tryParse(
        json['last_verified_at']?.toString() ?? '',
      ),
    );
  }
}
