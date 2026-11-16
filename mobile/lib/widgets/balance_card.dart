import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../ui/park_theme.dart';
import '../ui/park_widgets.dart';

class BalanceCard extends StatelessWidget {
  final int balance;
  final VoidCallback? onRechargePressed;
  const BalanceCard({super.key, required this.balance, this.onRechargePressed});
  @override
  Widget build(BuildContext context) => ParkCard(
    color: ParkColors.yellow,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Tu saldo disponible', style: TextStyle(fontSize: 12)),
        const SizedBox(height: 32),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            '\$' + NumberFormat.decimalPattern('es_CO').format(balance),
            style: const TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Text('COP · Billetera ParkU', style: TextStyle(fontSize: 11)),
        const SizedBox(height: 24),
        const Divider(color: Color(0x66FFFFFF)),
        const SizedBox(height: 8),
        if (onRechargePressed != null)
          TextButton(
            onPressed: onRechargePressed,
            child: const Text('Recarga presencial en taquilla'),
          )
        else
          const Text(
            'Recarga presencial en taquilla',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          ),
      ],
    ),
  );
}
