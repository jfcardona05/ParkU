import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../ui/park_shell.dart';
import '../ui/park_widgets.dart';
import '../widgets/recharge_history_card.dart';
import '../widgets/cash_closures_card.dart';

/// Uses the existing authorized recharge report API; grants no new permissions.
class TaquillaReportsScreen extends StatelessWidget {
  final ApiService apiService;
  const TaquillaReportsScreen({super.key, required this.apiService});

  @override
  Widget build(BuildContext context) => ParkShell(
    api: apiService,
    selected: 6,
    breadcrumb: 'Reportes de caja',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ParkHeading(
          'Cada recarga, bajo control.',
          'Consulta el recaudo registrado por día, semana o mes y busca comprobantes por usuario.',
        ),
        const ParkCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.fact_check_outlined),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Para revisar tu caja, elige la fecha y el período. El reporte incluye todos los operadores y puntos de atención; no representa un cierre de tu turno ni el efectivo contado.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        CashClosuresCard(api: apiService),
        const SizedBox(height: 24),
        RechargeHistoryCard(api: apiService),
      ],
    ),
  );
}
