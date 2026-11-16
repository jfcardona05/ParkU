import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/parking_service.dart';
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
  late Future<Map<String, dynamic>> _occupancy;
  @override
  void initState() {
    super.initState();
    _startLoad();
  }

  void _startLoad() {
    _data = _load();
    _occupancy = ParkingService(widget.apiService).getOccupancy();
    _data.ignore();
    _occupancy.ignore();
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

  void _qr(VehicleModel vehicle) => Navigator.push(
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
          ParkHeading('Hola, $name 👋', 'Todo listo para tu próxima entrada.'),
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
              final narrow = MediaQuery.sizeOf(context).width < 760;
              final balanceAndSpaces = ParkColumns(
                breakpoint: 480,
                children: [
                  BalanceCard(balance: balance),
                  ParkCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const ParkIcon(Icons.local_parking_outlined),
                        const SizedBox(height: 16),
                        const ParkBadge('Cupos disponibles', success: true),
                        const SizedBox(height: 24),
                        FutureBuilder(
                          future: _occupancy,
                          builder: (context, spaces) {
                            if (spaces.connectionState !=
                                ConnectionState.done) {
                              return const Text('Consultando…');
                            }
                            if (spaces.hasError) {
                              return const Text('Cupos no disponibles.');
                            }
                            final data = spaces.requireData;
                            return Text(
                              '${data['available']} / ${data['capacity']}',
                              style: Theme.of(context).textTheme.headlineMedium,
                            );
                          },
                        ),
                        const SizedBox(height: 28),
                        Text(
                          'Cupos libres · información del servidor',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        TextButton(
                          onPressed: () =>
                              ParkShell.open(context, widget.apiService, 3),
                          child: const Text('Consultar parqueadero →'),
                        ),
                      ],
                    ),
                  ),
                ],
              );
              final hero = ParkCard(
                color: ParkColors.yellow,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ParkIcon(Icons.directions_car_outlined),
                    const SizedBox(height: 18),
                    const Text(
                      'LLEGA. ESCANEA. PARQUEA.',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ParkColumns(
                      breakpoint: 430,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tu lugar empieza\ncon un QR.',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 18),
                            FilledButton(
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
                              child: Text(
                                vehicles.isEmpty
                                    ? 'Registrar vehículo →'
                                    : 'Ver mi QR →',
                              ),
                            ),
                          ],
                        ),
                        const ParkCar(),
                      ],
                    ),
                  ],
                ),
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (narrow) ...[balanceAndSpaces, const SizedBox(height: 20)],
                  ParkColumns(
                    flex: const [7, 4],
                    children: [
                      Column(
                        children: [
                          hero,
                          if (!narrow) ...[
                            const SizedBox(height: 20),
                            balanceAndSpaces,
                          ],
                        ],
                      ),
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
