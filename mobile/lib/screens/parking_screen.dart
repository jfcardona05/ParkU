import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/parking_service.dart';
import '../ui/park_shell.dart';
import '../ui/park_widgets.dart';
import '../ui/park_theme.dart';

class ParkingScreen extends StatefulWidget {
  final ApiService apiService;
  const ParkingScreen({super.key, required this.apiService});
  @override
  State<ParkingScreen> createState() => _ParkingScreenState();
}

class _ParkingScreenState extends State<ParkingScreen> {
  late final ParkingService _service;
  late Future<List<Map<String, dynamic>>> _rates;
  late Future<List<ParkedVehicle>> _vehicles;
  late Future<ParkingHistoryPage> _history;
  final List<Map<String, dynamic>> _moreOperations = [];
  ParkingHistoryPage? _lastPage;
  bool get _isCashier => widget.apiService.currentUser?.role == 'operador';
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
    _rates = _service.getRates();
    _vehicles = _isCashier ? Future.value([]) : _service.getVehicles();
    _history = _isCashier
        ? Future.value(const ParkingHistoryPage([], null))
        : _service.getHistory();
    _moreOperations.clear();
    _lastPage = null;
    _loadingMore = false;
    _pageError = null;
    // Each section displays its own error, even when another section is loading.
    _rates.ignore();
    _vehicles.ignore();
    _history.ignore();
  }

  Future<void> _refresh() async {
    setState(_startLoad);
    await Future.wait([
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
    Widget Function(T) content, {
    bool yellow = false,
  }) => ParkCard(
    color: yellow ? ParkColors.yellow : Colors.white,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: ParkIcon(Icons.local_parking_outlined),
        ),
        const SizedBox(height: 18),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 22),
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
                  Text(_message(snapshot.error)),
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
  Widget build(BuildContext context) => ParkShell(
    api: widget.apiService,
    selected: 3,
    breadcrumb: 'Parqueadero',
    refresh: _refresh,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ParkHeading(
          'Así está el parqueadero',
          _isCashier
              ? 'Cupos de parqueadero y tarifas vigentes.'
              : 'Tarifas, tu pase diario y tus accesos.',
        ),
        ParkColumns(
          children: [
            ParkAvailabilitySoon(yellow: true, showDefaultCapacity: _isCashier),
            _section(
              'Tarifas vigentes',
              _rates,
              (rates) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (rates.isEmpty) const Text('No hay tarifas disponibles.'),
                  for (final rate in rates)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rate['vehicle_type'] == 'moto'
                                ? 'Moto'
                                : 'Automóvil',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          Text('${rate['amount']} COP / pase diario'),
                          Text(
                            'Un único cobro al generar tu QR del día.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  Text(
                    'Se cobra al generar el QR. Consultarlo nuevamente no cobra otra vez.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
        if (!_isCashier) ...[
          const SizedBox(height: 20),
          _section('Tus últimos accesos', _history, (page) {
            final operations = [...page.operations, ..._moreOperations];
            final cursor = (_lastPage ?? page).nextBeforeId;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (operations.isEmpty)
                  const Text('No hay accesos registrados.'),
                for (final operation in operations)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFECECE8)),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${operation['action'] == 'entry' ? 'Ingreso' : 'Salida'} · ${operation['plate']}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          operation['occurred_at'].toString(),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (operation['charge']
                            case final Map<String, dynamic> charge) ...[
                          Text(
                            'Cobro ${charge['amount']} COP · Saldo posterior ${charge['balance_after']} COP',
                          ),
                          Text(
                            charge['parking_rate_label'].toString(),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
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
                const SizedBox(height: 12),
                Text(
                  'Solo se muestran tus vehículos y accesos.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            );
          }),
          const SizedBox(height: 20),
          _section(
            'Mis vehículos',
            _vehicles,
            (vehicles) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (vehicles.isEmpty)
                  const Text('Aún no tienes vehículos registrados.'),
                for (final parked in vehicles)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      parked.vehicle.isMoto
                          ? Icons.two_wheeler_outlined
                          : Icons.directions_car_outlined,
                    ),
                    title: Text(parked.vehicle.plate),
                    subtitle: Text(
                      parked.inside
                          ? 'Dentro del parqueadero'
                          : 'Fuera del parqueadero',
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const ParkFeatures(
            items: [
              (
                Icons.directions_car_outlined,
                'Tu vehículo',
                'Revisa si tienes un ingreso activo.',
              ),
              (
                Icons.local_parking_outlined,
                'Tarifa vigente',
                'El cobro se calcula en el servidor.',
              ),
              (
                Icons.history_outlined,
                'Tus accesos',
                'Consulta tus ingresos y salidas.',
              ),
            ],
          ),
        ],
      ],
    ),
  );
}
