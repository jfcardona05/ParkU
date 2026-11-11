class TransactionModel {
  static const inPersonRechargeType = 'RECARGA_PRESENCIAL';

  // Category used by Flutter adapters for a confirmed parking debit.
  static const parkingChargeType = 'COBRO_ESTACIONAMIENTO';

  final int id;
  final String type;
  final int amount;
  final String pointName;
  final String reference;
  final int balanceAfter;
  final String createdAt;

  // Display value supplied by the parking adapter once its contract is agreed.
  final String? parkingRateLabel;

  TransactionModel({
    required this.id,
    required this.type,
    required this.amount,
    required this.pointName,
    required this.reference,
    required this.balanceAfter,
    required this.createdAt,
    this.parkingRateLabel,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] as int? ?? 0,
      type: json['type'] as String? ?? inPersonRechargeType,
      amount: json['amount'] as int? ?? 0,
      pointName:
          json['point_name'] as String? ?? 'Punto 1 - Portería Principal USTA',
      reference: json['reference'] as String? ?? '',
      balanceAfter: json['balance_after'] as int? ?? 0,
      createdAt: json['created_at'] as String? ?? '',
      parkingRateLabel: json['parking_rate_label'] as String?,
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
      if (parkingRateLabel != null) 'parking_rate_label': parkingRateLabel,
    };
  }
}
