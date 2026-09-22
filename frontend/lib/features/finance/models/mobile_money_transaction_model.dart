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
        return 'Créé';
      case 'pending':
      case 'processing':
        return 'En vérification';
      case 'successful':
        return 'Confirmé';
      case 'failed':
        return 'Refusé';
      case 'cancelled':
        return 'Annulé';
      case 'expired':
        return 'Expiré';
      case 'refunded':
        return 'Remboursé';
      default:
        return status;
    }
  }
}
