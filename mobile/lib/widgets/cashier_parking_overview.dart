import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';
import '../ui/park_shell.dart';
import '../ui/park_theme.dart';
import '../ui/park_widgets.dart';

/// A read-only snapshot of the operator's current session, never a cash close.
class CashierParkingSummary extends StatelessWidget {
  final Map<String, dynamic> data;
  const CashierParkingSummary({super.key, required this.data});

  Widget _metric(
    BuildContext context,
    String label,
    Object? value, {
    bool money = true,
  }) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: ParkColors.background,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        Text(
          value is num
              ? '${NumberFormat.decimalPattern('es_CO').format(value)}${money ? ' COP' : ''}'
              : 'No disponible',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final session = data['session'] as Map<String, dynamic>?;
    final ready = session?['can_recharge'] == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: ParkBadge(
            session == null
                ? 'Sin caja abierta'
                : ready
                ? 'Caja abierta'
                : 'Cierre pendiente',
            success: ready,
          ),
        ),
        const SizedBox(height: 16),
        if (session == null)
          const Text(
            'Abre tu caja desde Panel de caja para comenzar la atención. Aquí verás el resumen de tu turno activo.',
          )
        else ...[
          Text(
            '${session['point_name']}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text('Fecha del turno: ${session['business_date']}'),
          if (!ready) ...[
            const SizedBox(height: 12),
            const Text(
              'Este turno requiere cierre. Revísalo en Panel de caja antes de registrar nuevos ingresos.',
            ),
          ],
          const SizedBox(height: 18),
          ParkColumns(
            children: [
              _metric(context, 'Recaudo del turno', session['recharge_total']),
              _metric(
                context,
                'Cobros y recargas',
                session['recharge_count'],
                money: false,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ParkColumns(
            children: [
              _metric(context, 'Base de apertura', session['opening_amount']),
              _metric(context, 'Efectivo esperado', session['expected_cash']),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Incluye los ingresos de tu caja. El efectivo esperado suma la base de apertura y el recaudo; se confirma mediante conteo al cerrar.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 12),
        Text(
          'Usa Actualizar para consultar el estado más reciente. El historial y los comprobantes se consultan en Reportes.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class CashierParkingActions extends StatelessWidget {
  final ApiService api;
  const CashierParkingActions({super.key, required this.api});

  @override
  Widget build(BuildContext context) => ParkColumns(
    children: [
      ParkCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ParkIcon(Icons.point_of_sale_outlined),
            const SizedBox(height: 18),
            Text(
              'Atención rápida',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            const Text(
              'Gestiona recargas, pases de visitantes y el cierre desde tu puesto de atención.',
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => ParkShell.open(context, api, 5),
              icon: const Icon(Icons.point_of_sale_outlined),
              label: const Text('Ir al panel de caja'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => ParkShell.open(context, api, 6),
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('Consultar reportes'),
            ),
          ],
        ),
      ),
      ParkCard(
        color: ParkColors.yellowLight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ParkIcon(Icons.fact_check_outlined),
            const SizedBox(height: 18),
            Text(
              'Una atención ordenada',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(child: Text('1')),
              title: Text('Prepara tu caja'),
              subtitle: Text(
                'Confirma el punto y la base para devueltas antes de atender.',
              ),
            ),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(child: Text('2')),
              title: Text('Verifica cada operación'),
              subtitle: Text(
                'Revisa el destinatario o la placa y el efectivo recibido antes de confirmar.',
              ),
            ),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(child: Text('3')),
              title: Text('Entrega el turno con claridad'),
              subtitle: Text(
                'Cuenta el efectivo, separa la base de devueltas y genera el comprobante de cierre.',
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
