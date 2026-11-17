import 'package:flutter/material.dart';
import '../ui/park_glyph.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../ui/park_theme.dart';

class WalletMovementTile extends StatelessWidget {
  final TransactionModel movement;
  const WalletMovementTile({super.key, required this.movement});
  @override
  Widget build(BuildContext context) {
    final recharge = movement.type == TransactionModel.inPersonRechargeType;
    final debit =
        movement.type == TransactionModel.parkingChargeType ||
        movement.amount < 0;
    final format = NumberFormat.decimalPattern('es_CO');
    final sign = debit ? '−' : (recharge ? '+' : '');
    final color = debit ? ParkColors.ink : ParkColors.green;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFECECE8))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: recharge ? ParkColors.greenLight : ParkColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              debit
                  ? Icons.sensor_door_outlined
                  : Icons.account_balance_wallet_outlined,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  debit
                      ? 'Cobro de estacionamiento'
                      : (recharge ? 'Recarga presencial' : 'Movimiento'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 5),
                if (movement.createdAt.isNotEmpty)
                  Text(
                    movement.createdAt,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                if (movement.pointName.isNotEmpty)
                  Text(
                    movement.pointName,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                if (movement.parkingRateLabel case final rate?
                    when rate.isNotEmpty)
                  Text(
                    'Tarifa aplicada: $rate',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                if (movement.reference.isNotEmpty)
                  Text(
                    'Ref. ${movement.reference}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                Text(
                  'Saldo posterior: \$${format.format(movement.balanceAfter)} COP',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
                Text(
                  '$sign\$${format.format(movement.amount.abs())} COP',
                  style: TextStyle(color: color, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
