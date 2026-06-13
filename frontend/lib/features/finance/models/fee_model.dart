class FeeModel {
  final String id;
  final String userId;
  final String? seasonId;
  final String type;
  final String label;
  final double amount;
  final double amountPaid;
  final String status;
  final String? dueDate;
  final String? createdAt;

  const FeeModel({
    required this.id,
    required this.userId,
    this.seasonId,
    required this.type,
    required this.label,
    required this.amount,
    required this.amountPaid,
    required this.status,
    this.dueDate,
    this.createdAt,
  });

  factory FeeModel.fromJson(Map<String, dynamic> json) {
    return FeeModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      seasonId: json['season_id']?.toString(),
      type: json['type']?.toString() ?? '',
      label: json['label']?.toString() ?? 'Frais',
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0,
      amountPaid: double.tryParse(json['amount_paid']?.toString() ?? '0') ?? 0,
      status: json['status']?.toString() ?? 'unpaid',
      dueDate: json['due_date']?.toString(),
      createdAt: json['created_at']?.toString(),
    );
  }

  double get remainingAmount {
    final remaining = amount - amountPaid;
    return remaining < 0 ? 0 : remaining;
  }

  String get statusLabel {
    switch (status) {
      case 'unpaid':
        return 'Non payé';
      case 'partial':
        return 'Partiel';
      case 'paid':
        return 'Payé';
      default:
        return status;
    }
  }

  String get typeLabel {
    switch (type) {
      case 'cotisation':
        return 'Cotisation';
      case 'penalty':
      case 'penalite':
        return 'Pénalité';
      case 'event':
        return 'Événement';
      default:
        return type.isEmpty ? 'Frais' : type;
    }
  }
}
