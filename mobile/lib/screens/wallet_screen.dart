import 'package:flutter/material.dart';

import '../models/transaction_model.dart';
import '../services/api_service.dart';
import '../services/parking_service.dart';
import '../widgets/balance_card.dart';
import '../widgets/load_error.dart';
import '../widgets/wallet_movement_tile.dart';

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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E17),
      body: FutureBuilder(
        future: _wallet,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final error = snapshot.error;
            return LoadError(
              message: error is ApiException
                  ? error.message
                  : 'No se pudo cargar el saldo y los movimientos.',
              retry: _refresh,
            );
          }

          final (balance, movements) = snapshot.requireData;
          return SafeArea(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Saldo y movimientos',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _refresh,
                        tooltip: 'Actualizar saldo y movimientos',
                        icon: const Icon(Icons.refresh, color: Colors.white70),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  BalanceCard(balance: balance),
                  const SizedBox(height: 12),
                  FutureBuilder(
                    future: _parkingStatus,
                    builder: (context, parking) {
                      final status = switch ((
                        parking.connectionState,
                        parking.data,
                      )) {
                        (ConnectionState.waiting, _) => 'Consultando estado…',
                        (_, ParkingStatus.outside) => 'Sin ingreso activo.',
                        (_, ParkingStatus.inside) =>
                          'Tienes un ingreso activo.',
                        (_, ParkingStatus.insufficientBalance) =>
                          'Saldo insuficiente para completar la salida.',
                        _ => 'Consulta de estado no disponible.',
                      };
                      return Card(
                        color: const Color(0xFF111827),
                        child: ListTile(
                          leading: const Icon(
                            Icons.local_parking,
                            color: Colors.white70,
                          ),
                          title: const Text(
                            'Estacionamiento',
                            style: TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            status,
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Puntos de recarga autorizados',
                    style: TextStyle(
                      color: Color(0xFFF59E0B),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'Portería Principal (Entrada vehicular)\n'
                    'Cafetería Central (Edificio Santo Domingo)',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Historial de movimientos',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (movements.isEmpty)
                    const Text(
                      'No hay movimientos registrados.',
                      style: TextStyle(color: Colors.white70),
                    )
                  else
                    for (final movement in movements)
                      WalletMovementTile(movement: movement),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
