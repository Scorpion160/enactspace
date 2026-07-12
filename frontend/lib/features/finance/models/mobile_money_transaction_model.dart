class MobileMoneyTransactionModel {
  final String transactionId;
  final int amount;
  final String currency;
  final String status;
  final String? checkoutUrl;
  final DateTime? expiresAt;
  final String message;

  const MobileMoneyTransactionModel({
    required this.transactionId,
    required this.amount,
    required this.currency,
    required this.status,
    this.checkoutUrl,
    this.expiresAt,
    required this.message,
  });

  factory MobileMoneyTransactionModel.fromJson(Map<String, dynamic> json) {
    return MobileMoneyTransactionModel(
      transactionId: json['transaction_id']?.toString() ?? '',
      amount: int.tryParse(json['amount']?.toString() ?? '0') ?? 0,
      currency: json['currency']?.toString() ?? 'XOF',
      status: json['status']?.toString() ?? 'pending',
      checkoutUrl: json['checkout_url']?.toString(),
      expiresAt: DateTime.tryParse(json['expires_at']?.toString() ?? ''),
      message: json['message']?.toString() ?? 'Paiement en cours.',
    );
  }

  bool get isFinal {
    return {
      'successful',
      'failed',
      'cancelled',
      'expired',
      'refunded',
    }.contains(status);
  }

  String get statusLabel {
    switch (status) {
      case 'created':
        return 'Cree';
      case 'pending':
      case 'processing':
        return 'En verification';
      case 'successful':
        return 'Confirme';
      case 'failed':
        return 'Refuse';
      case 'cancelled':
        return 'Annule';
      case 'expired':
        return 'Expire';
      case 'refunded':
        return 'Rembourse';
      default:
        return status;
    }
  }
}
