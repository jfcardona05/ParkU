import '../widgets/load_error.dart';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../models/vehicle_model.dart';
import '../ui/park_shell.dart';
import '../ui/park_widgets.dart';
import '../ui/park_theme.dart';
import '../ui/vehicle_card.dart';
import 'add_vehicle_screen.dart';
import 'vehicle_qr_screen.dart';
import '../services/vehicle_qr_service.dart';

class VehiclesScreen extends StatefulWidget {
  final ApiService apiService;

  const VehiclesScreen({super.key, required this.apiService});

  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  String? _loadError;
  bool _isLoading = true;
  List<VehicleModel> _vehicles = [];

  @override
  void initState() {
    super.initState();
    _fetchVehicles();
  }

  Future<void> _fetchVehicles() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final list = await widget.apiService.getVehicles();
      if (!mounted) return;
      setState(() {
        _vehicles = list;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _isLoading = false;
      });
    }
  }

  void _openAddVehicle() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddVehicleScreen(apiService: widget.apiService),
      ),
    );
    if (result == true) {
      _fetchVehicles();
    }
  }

  void _deleteVehicle(VehicleModel v) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          'Desvincular Vehículo',
          style: TextStyle(color: ParkColors.ink),
        ),
        content: Text(
          '¿Deseas desvincular el vehículo con placa ${v.plate} de tu cuenta?',
          style: const TextStyle(color: ParkColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: ParkColors.muted),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Desvincular',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final ok = await widget.apiService.deleteVehicle(v.id);
        if (ok) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Vehículo ${v.plate} desvinculado.')),
          );
          _fetchVehicles();
        }
      } on ApiException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  void _openQr(VehicleModel vehicle) => Navigator.push(
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
  Widget build(BuildContext context) => ParkShell(
    api: widget.apiService,
    selected: 1,
    breadcrumb: 'Vehículos',
    refresh: _fetchVehicles,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ParkHeading('Tus vehículos', 'Tu QR seguro, siempre a mano.'),
        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else if (_loadError != null)
          LoadError(message: _loadError!, retry: _fetchVehicles)
        else ...[
          ParkColumns(
            flex: const [4, 7],
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_vehicles.isEmpty)
                    const ParkNotice('Aún no tienes vehículos registrados.'),
                  for (final vehicle in _vehicles)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: ParkVehicleCard(
                        key: ValueKey(vehicle.id),
                        vehicle: vehicle,
                        api: widget.apiService,
                        onQr: () => _openQr(vehicle),
                        onDelete: () => _deleteVehicle(vehicle),
                      ),
                    ),
                ],
              ),
              ParkCard(
                color: ParkColors.yellow,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ParkIcon(Icons.directions_car_outlined),
                    const SizedBox(height: 22),
                    Text(
                      'Un vehículo.\nTu próximo recorrido.',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Registra los vehículos de tu propiedad y genera su QR antes de llegar a portería.',
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                      ),
                      onPressed: _openAddVehicle,
                      child: const Text('+ Agregar vehículo'),
                    ),
                    const SizedBox(height: 28),
                    const ParkCar(),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const ParkCard(
            padding: EdgeInsets.all(18),
            child: Text(
              'Solo tú puedes ver y administrar tus vehículos.',
              style: TextStyle(color: ParkColors.muted, fontSize: 12),
            ),
          ),
          const SizedBox(height: 20),
          const ParkFeatures(
            items: [
              (
                Icons.directions_car_outlined,
                '01 · Registra',
                'Agrega la placa y el tipo de tu vehículo.',
              ),
              (
                Icons.qr_code_2_outlined,
                '02 · Genera tu QR',
                'El código es temporal y de un solo uso.',
              ),
              (
                Icons.sensor_door_outlined,
                '03 · Preséntalo',
                'Portería valida y confirma la operación.',
              ),
            ],
          ),
        ],
      ],
    ),
  );
}
