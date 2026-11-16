import 'package:flutter/material.dart';

import '../models/transaction_model.dart';
import '../services/api_service.dart';
import '../services/parking_service.dart';
import '../widgets/balance_card.dart';
import '../widgets/load_error.dart';
import '../widgets/wallet_movement_tile.dart';
import '../ui/park_shell.dart';
import '../ui/park_widgets.dart';
import '../ui/park_theme.dart';

enum ParkingStatus { outside, inside, insufficientBalance }

class WalletScreen extends StatefulWidget {
  final ApiService apiService;
  final Future<ParkingStatus> Function()? loadParkingStatus;

  const WalletScreen({
    super.key,
    required this.apiService,
    this.loadParkingStatus,
  });

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  late Future<(int, List<TransactionModel>)> _wallet;
  Future<ParkingStatus?>? _parkingStatus;

  @override
  void initState() {
    super.initState();
    _startLoad();
  }

  Future<(int, List<TransactionModel>)> _loadWallet() async {
    final balance = await widget.apiService.getBalance();
    final history = await widget.apiService.getHistory();
    return (balance, history);
  }

  void _startLoad() {
    _wallet = _loadWallet();
    final loadParkingStatus =
        widget.loadParkingStatus ??
        () async {
          final vehicles = await ParkingService(
            widget.apiService,
          ).getVehicles();
          return vehicles.any((vehicle) => vehicle.inside)
              ? ParkingStatus.inside
              : ParkingStatus.outside;
        };
    _parkingStatus = _loadParkingStatus(loadParkingStatus);
  }

  Future<ParkingStatus?> _loadParkingStatus(
    Future<ParkingStatus> Function() load,
  ) async {
    try {
      return await load();
    } on Object {
      // A parking outage must not hide the balance or wallet history.
      return null;
    }
  }

  Future<void> _refresh() async {
    setState(_startLoad);
    try {
      await _wallet;
    } on Object {
      // The FutureBuilder displays the failure and lets the user retry.
    }
  }

  @override
  Widget build(BuildContext context) => ParkShell(
    api: widget.apiService,
    selected: 2,
    breadcrumb: 'Mi saldo',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ParkHeading(
          'Tu saldo, al día',
          'Consulta tus recargas y cobros.',
          action: IconButton(
            onPressed: _refresh,
            tooltip: 'Actualizar saldo y movimientos',
            icon: const Icon(Icons.refresh),
          ),
        ),
        FutureBuilder(
          future: _wallet,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done)
              return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError)
              return LoadError(
                message: snapshot.error is ApiException
                    ? (snapshot.error as ApiException).message
                    : 'No se pudo cargar el saldo y los movimientos.',
                retry: _refresh,
              );
            final (balance, movements) = snapshot.requireData;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ParkColumns(
                  flex: const [4, 7],
                  children: [
                    BalanceCard(balance: balance),
                    const ParkCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ParkIcon(Icons.storefront_outlined),
                          SizedBox(height: 20),
                          Text(
                            'Recarga en taquilla',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 32),
                          Text(
                            'Acércate al operador autorizado. Tu recarga aparecerá en el historial al ser registrada.',
                            style: TextStyle(color: ParkColors.muted),
                          ),
                          SizedBox(height: 24),
                          ParkBadge('Sin pagos en línea'),
                          SizedBox(height: 18),
                          Text(
                            'Portería Principal · Cafetería Central',
                            style: TextStyle(
                              fontSize: 11,
                              color: ParkColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                FutureBuilder(
                  future: _parkingStatus,
                  builder: (context, parking) {
                    final status = switch ((
                      parking.connectionState,
                      parking.data,
                    )) {
                      (ConnectionState.waiting, _) => 'Consultando estado…',
                      (_, ParkingStatus.outside) => 'Sin ingreso activo.',
                      (_, ParkingStatus.inside) => 'Tienes un ingreso activo.',
                      (_, ParkingStatus.insufficientBalance) =>
                        'Saldo insuficiente para completar la salida.',
                      _ => 'Consulta de estado no disponible.',
                    };
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Text(
                        status,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    );
                  },
                ),
                ParkCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tus movimientos',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      if (movements.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Text('No hay movimientos registrados.'),
                        ),
                      for (final movement in movements)
                        WalletMovementTile(movement: movement),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const ParkFeatures(
                  items: [
                    (
                      Icons.storefront_outlined,
                      'Recarga presencial',
                      'Acércate a taquilla con tu cuenta ParkU.',
                    ),
                    (
                      Icons.local_parking_outlined,
                      'Cobro transparente',
                      'Consulta los cobros en tus movimientos.',
                    ),
                    (
                      Icons.history_outlined,
                      'Historial personal',
                      'Tus movimientos se mantienen privados.',
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    ),
  );
}
