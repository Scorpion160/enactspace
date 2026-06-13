class PaymentModel {
  final String id;
  final String userId;
  final double amount;
  final String method;
  final String status;
  final String? reference;
  final String? proofUrl;
  final String? createdAt;
  final String? validatedAt;

  const PaymentModel({
    required this.id,
    required this.userId,
    required this.amount,
    required this.method,
    required this.status,
    this.reference,
    this.proofUrl,
    this.createdAt,
    this.validatedAt,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0,
      method: json['method']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      reference: json['reference']?.toString(),
      proofUrl: json['proof_url']?.toString(),
      createdAt: json['created_at']?.toString(),
      validatedAt: json['validated_at']?.toString(),
    );
  }

  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'En attente';
      case 'validated':
        return 'Validé';
      case 'cancelled':
        return 'Annulé';
      default:
        return status;
    }
  }

  String get methodLabel {
    switch (method) {
      case 'cash':
        return 'Espèces';
      case 'wave':
        return 'Wave';
      case 'orange_money':
        return 'Orange Money';
      case 'bank':
        return 'Banque';
      default:
        return method;
    }
  }
}
