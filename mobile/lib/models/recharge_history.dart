class RechargeRecord {
  final int id;
  final String incomeType;
  final String plate;
  final int? visitorPassId;
  final int amount;
  final String userName;
  final String userEmail;
  final String operatorName;
  final String pointName;
  final String reference;
  final DateTime createdAt;
  const RechargeRecord({
    this.incomeType = 'RECARGA_USUARIO',
    this.plate = '',
    this.visitorPassId,
    required this.id,
    required this.amount,
    required this.userName,
    required this.userEmail,
    required this.operatorName,
    required this.pointName,
    required this.reference,
    required this.createdAt,
  });
  factory RechargeRecord.fromJson(Map<String, dynamic> json) => RechargeRecord(
    incomeType: json['income_type'] as String? ?? 'RECARGA_USUARIO',
    plate: json['plate'] as String? ?? '',
    visitorPassId: (json['visitor_pass_id'] as num?)?.toInt(),
    id: (json['id'] as num).toInt(),
    amount: (json['amount'] as num).toInt(),
    userName: json['user_name'] as String,
    userEmail: json['user_email'] as String,
    operatorName: json['operator_name'] as String,
    pointName: json['point_name'] as String,
    reference: json['reference'] as String,
    createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
  );
}

class RechargeHistoryPage {
  final String from;
  final String through;
  final int totalAmount;
  final int count;
  final int userCount;
  final bool hasMore;
  final List<RechargeRecord> recharges;
  const RechargeHistoryPage({
    required this.from,
    required this.through,
    required this.totalAmount,
    required this.count,
    required this.userCount,
    required this.hasMore,
    required this.recharges,
  });
  factory RechargeHistoryPage.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] as Map<String, dynamic>;
    return RechargeHistoryPage(
      from: json['from'] as String,
      through: json['through'] as String,
      totalAmount: (summary['total_amount'] as num).toInt(),
      count: (summary['count'] as num).toInt(),
      userCount: (summary['user_count'] as num).toInt(),
      hasMore: json['has_more'] as bool,
      recharges: (json['recharges'] as List)
          .map((e) => RechargeRecord.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
