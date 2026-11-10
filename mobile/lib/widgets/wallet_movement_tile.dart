import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/transaction_model.dart';

class WalletMovementTile extends StatelessWidget {
  final TransactionModel movement;
  const WalletMovementTile({super.key, required this.movement});

  @override
  Widget build(BuildContext context) {
    final isRecharge = movement.type == TransactionModel.inPersonRechargeType;
    final isParkingCharge = movement.type == TransactionModel.parkingChargeType;
    final isDebit = isParkingCharge || movement.amount < 0;
    final color = isDebit
        ? const Color(0xFFFCA5A5)
        : isRecharge
        ? const Color(0xFF34D399)
        : const Color(0xFFD1D5DB);
    final sign = isDebit ? '−' : (isRecharge ? '+' : '');
    final format = NumberFormat.decimalPattern('es_CO');
    final title = isParkingCharge
        ? 'Cobro de estacionamiento'
        : isRecharge
        ? 'Recarga presencial'
        : 'Movimiento';
    final details = [
      if (movement.pointName.isNotEmpty) movement.pointName,
      if (movement.parkingRateLabel case final rate? when rate.isNotEmpty)
        'Tarifa aplicada: $rate',
      if (movement.createdAt.isNotEmpty) movement.createdAt,
      if (movement.reference.isNotEmpty) 'Ref. ${movement.reference}',
    ];

    return Card(
      color: const Color(0xFF111827),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isDebit ? Icons.remove_circle_outline : Icons.receipt_long,
              color: color,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white)),
                  for (final detail in details)
                    Text(detail, style: const TextStyle(color: Colors.white70)),
                  Text(
                    '$sign\$${format.format(movement.amount.abs())} COP',
                    style: TextStyle(color: color, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Saldo posterior: \$${format.format(movement.balanceAfter)} COP',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
