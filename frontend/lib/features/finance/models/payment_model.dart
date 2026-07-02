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
  final String? rejectedAt;
  final String? rejectionReason;
  final bool canValidate;
  final bool canReject;
  final bool canCancel;

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
    this.rejectedAt,
    this.rejectionReason,
    required this.canValidate,
    required this.canReject,
    required this.canCancel,
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
      rejectedAt: json['rejected_at']?.toString(),
      rejectionReason: json['rejection_reason']?.toString(),
      canValidate: json['can_validate'] == true,
      canReject: json['can_reject'] == true,
      canCancel: json['can_cancel'] == true,
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
      case 'rejected':
        return 'Rejete';
      default:
        return status;
    }
  }

  String get methodLabel {
    switch (method) {
      case 'manuel':
        return 'Saisie manuelle';
      case 'especes':
        return 'Espèces';
      case 'wave':
        return 'Wave';
      case 'orange_money':
        return 'Orange Money';
      case 'free_money':
        return 'Free Money';
      case 'bank_transfer':
        return 'Virement bancaire';
      default:
        return method;
    }
  }
}
