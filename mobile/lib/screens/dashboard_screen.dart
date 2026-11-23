import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/vehicle_qr_service.dart';
import '../models/vehicle_model.dart';
import '../models/transaction_model.dart';
import '../widgets/balance_card.dart';
import '../widgets/wallet_movement_tile.dart';
import '../widgets/load_error.dart';
import '../ui/park_shell.dart';
import '../ui/park_widgets.dart';
import '../ui/park_theme.dart';
import '../ui/vehicle_card.dart';
import 'vehicle_qr_screen.dart';

class DashboardScreen extends StatefulWidget {
  final ApiService apiService;
  const DashboardScreen({super.key, required this.apiService});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<(int, List<VehicleModel>, List<TransactionModel>)> _data;
  @override
  void initState() {
    super.initState();
    _startLoad();
  }

  void _startLoad() {
    _data = _load();
    _data.ignore();
  }

  Future<(int, List<VehicleModel>, List<TransactionModel>)> _load() async {
    final balance = await widget.apiService.getBalance();
    final vehicles = await widget.apiService.getVehicles();
    final history = await widget.apiService.getHistory();
    return (balance, vehicles, history);
  }

  Future<void> _refresh() async {
    setState(_startLoad);
    try {
      await _data;
    } catch (_) {}
  }

  Future<void> _qr(VehicleModel vehicle) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VehicleQrScreen(
          vehicle: vehicle,
          apiService: widget.apiService,
          source: const bool.fromEnvironment('PARKU_QR_DEMO')
              ? DemoVehicleQrSource()
              : ApiVehicleQrSource(widget.apiService),
        ),
      ),
    );
    if (mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final name =
        widget.apiService.currentUser?.name.trim().split(' ').first ??
        'Usuario';
    return ParkShell(
      api: widget.apiService,
      selected: 0,
      breadcrumb: 'Inicio',
      refresh: _refresh,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ParkHeading(
            'Hola, $name',
            'Todo listo para tu próxima entrada.',
            action: const Padding(
              padding: EdgeInsets.only(top: 5),
              child: Icon(
                Icons.waving_hand_outlined,
                color: ParkColors.ink,
                size: 26,
              ),
            ),
          ),
          FutureBuilder(
            future: _data,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return LoadError(
                  message: snapshot.error is ApiException
                      ? (snapshot.error as ApiException).message
                      : 'No se pudo cargar el inicio.',
                  retry: _refresh,
                );
              }
              final (balance, vehicles, history) = snapshot.requireData;
              final hero = ParkCard(
                color: ParkColors.yellow,
                child: LayoutBuilder(
                  builder: (context, size) => Row(
                    children: [
                      Expanded(
                        flex: 7,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'TU PRÓXIMA ENTRADA',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Tu lugar empieza\ncon un QR.',
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(
                                    fontSize: size.maxWidth < 420 ? 26 : 34,
                                  ),
                            ),
                            const SizedBox(height: 18),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.white,
                              ),
                              onPressed: vehicles.isEmpty
                                  ? () => ParkShell.open(
                                      context,
                                      widget.apiService,
                                      1,
                                    )
                                  : () => _qr(vehicles.first),
                              icon: const Icon(Icons.qr_code_2, size: 19),
                              label: Text(
                                vehicles.isEmpty
                                    ? 'Registrar vehículo'
                                    : 'Ver mi QR →',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        flex: 3,
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: .6),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: const FittedBox(
                              child: Padding(
                                padding: EdgeInsets.all(12),
                                child: Icon(Icons.qr_code_2, size: 88),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ParkColumns(
                    flex: const [7, 4],
                    children: [
                      hero,
                      BalanceCard(balance: balance),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ParkColumns(
                    flex: const [7, 4],
                    children: [
                      if (vehicles.isEmpty)
                        const ParkNotice(
                          'Registra tu primer vehículo para generar un QR.',
                        )
                      else
                        ParkVehicleCard(
                          key: ValueKey(_data),
                          vehicle: vehicles.first,
                          api: widget.apiService,
                          onQr: () => _qr(vehicles.first),
                        ),
                      const ParkAvailabilitySoon(),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ParkCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tus últimos movimientos',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        if (history.isEmpty)
                          const Text('No hay movimientos registrados.'),
                        for (final tx in history.take(3))
                          WalletMovementTile(movement: tx),
                        TextButton(
                          onPressed: () =>
                              ParkShell.open(context, widget.apiService, 2),
                          child: const Text('Ver todos mis movimientos →'),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
