class TransactionModel {
  final int id;
  final String type;
  final int amount;
  final String pointName;
  final String reference;
  final int balanceAfter;
  final String createdAt;

  TransactionModel({
    required this.id,
    required this.type,
    required this.amount,
    required this.pointName,
    required this.reference,
    required this.balanceAfter,
    required this.createdAt,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] as int? ?? 0,
      type: json['type'] as String? ?? 'RECARGA_PRESENCIAL',
      amount: json['amount'] as int? ?? 0,
      pointName:
          json['point_name'] as String? ?? 'Punto 1 - Portería Principal USTA',
      reference: json['reference'] as String? ?? '',
      balanceAfter: json['balance_after'] as int? ?? 0,
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'amount': amount,
      'point_name': pointName,
      'reference': reference,
      'balance_after': balanceAfter,
      'created_at': createdAt,
    };
  }
}
