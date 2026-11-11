import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/parking_service.dart';

class ParkingScreen extends StatefulWidget {
  final ApiService apiService;
  const ParkingScreen({super.key, required this.apiService});
  @override
  State<ParkingScreen> createState() => _ParkingScreenState();
}

class _ParkingScreenState extends State<ParkingScreen> {
  late final ParkingService _service;
  late Future<Map<String, dynamic>> _occupancy;
  late Future<List<Map<String, dynamic>>> _rates;
  late Future<List<ParkedVehicle>> _vehicles;
  late Future<ParkingHistoryPage> _history;
  final List<Map<String, dynamic>> _moreOperations = [];
  ParkingHistoryPage? _lastPage;
  bool _loadingMore = false;
  String? _pageError;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _service = ParkingService(widget.apiService);
    _startLoad();
  }

  void _startLoad() {
    _generation++;
    _occupancy = _service.getOccupancy();
    _rates = _service.getRates();
    _vehicles = _service.getVehicles();
    _history = _service.getHistory();
    _moreOperations.clear();
    _lastPage = null;
    _loadingMore = false;
    _pageError = null;
    // Each section displays its own error, even when another section is loading.
    _occupancy.ignore();
    _rates.ignore();
    _vehicles.ignore();
    _history.ignore();
  }

  Future<void> _refresh() async {
    setState(_startLoad);
    await Future.wait([
      _occupancy.then<void>((_) {}, onError: (_) {}),
      _rates.then<void>((_) {}, onError: (_) {}),
      _vehicles.then<void>((_) {}, onError: (_) {}),
      _history.then<void>((_) {}, onError: (_) {}),
    ]);
  }

  String _message(Object? error) => error is ApiException
      ? error.message
      : 'No se pudo cargar esta información. Intenta nuevamente.';

  Widget _section<T>(
    String title,
    Future<T> future,
    Widget Function(T) content,
  ) => Card(
    color: const Color(0xFF111827),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<T>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _message(snapshot.error),
                      style: const TextStyle(color: Colors.white70),
                    ),
                    TextButton(
                      onPressed: _refresh,
                      child: const Text('Reintentar'),
                    ),
                  ],
                );
              }
              return content(snapshot.requireData);
            },
          ),
        ],
      ),
    ),
  );

  Future<void> _loadMore(int cursor) async {
    if (_loadingMore) return;
    final generation = _generation;
    setState(() {
      _loadingMore = true;
      _pageError = null;
    });
    try {
      final page = await _service.getHistory(beforeId: cursor);
      if (!mounted || generation != _generation) return;
      setState(() {
        _moreOperations.addAll(page.operations);
        _lastPage = page;
      });
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _pageError = _message(error));
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loadingMore = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Parqueadero'),
      actions: [
        IconButton(
          onPressed: _refresh,
          tooltip: 'Actualizar parqueadero',
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: _refresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _section(
              'Cupos',
              _occupancy,
              (data) => Text(
                'Disponibles ${data['available']} · Ocupados ${data['occupied']} · Capacidad ${data['capacity']}',
                style: const TextStyle(color: Colors.white70),
              ),
            ),
            _section(
              'Tarifas vigentes',
              _rates,
              (rates) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (rates.isEmpty) const Text('No hay tarifas disponibles.'),
                  for (final rate in rates)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        rate['vehicle_type'] == 'moto' ? 'Moto' : 'Automóvil',
                      ),
                      subtitle: Text(
                        '${rate['amount']} COP por bloque iniciado de ${rate['block_seconds']} segundos. Mínimo ${rate['minimum_blocks']} bloque(s).',
                      ),
                    ),
                  const Text(
                    'Se aplica la tarifa vigente al ingresar.',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            _section(
              'Mis vehículos',
              _vehicles,
              (vehicles) => Column(
                children: [
                  if (vehicles.isEmpty)
                    const Text('Aún no tienes vehículos registrados.'),
                  for (final parked in vehicles)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(parked.vehicle.plate),
                      subtitle: Text(
                        parked.inside
                            ? 'Dentro del parqueadero${parked.enteredAt == null ? '' : ' · Ingreso ${parked.enteredAt!.toLocal()}'}'
                            : 'Fuera del parqueadero',
                      ),
                    ),
                ],
              ),
            ),
            _section('Historial de accesos', _history, (page) {
              final operations = [...page.operations, ..._moreOperations];
              final cursor = (_lastPage ?? page).nextBeforeId;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (operations.isEmpty)
                    const Text('No hay accesos registrados.'),
                  for (final operation in operations)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${operation['action'] == 'entry' ? 'Ingreso' : 'Salida'} · ${operation['plate']}',
                      ),
                      subtitle: Text(
                        [
                          operation['occurred_at'] as String,
                          if (operation['charge']
                              case final Map<String, dynamic> charge) ...[
                            'Cobro ${charge['amount']} COP · Saldo posterior ${charge['balance_after']} COP',
                            charge['parking_rate_label'] as String,
                          ],
                        ].join('\n'),
                      ),
                    ),
                  if (_pageError != null) Text(_pageError!),
                  if (cursor != null)
                    TextButton(
                      onPressed: _loadingMore ? null : () => _loadMore(cursor),
                      child: Text(
                        _loadingMore ? 'Cargando…' : 'Cargar más accesos',
                      ),
                    ),
                ],
              );
            }),
          ],
        ),
      ),
    ),
  );
}
