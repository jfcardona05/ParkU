import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/vehicle_model.dart';
import '../services/api_service.dart';
import '../services/vehicle_qr_service.dart';
import '../ui/park_shell.dart';
import '../ui/park_widgets.dart';
import '../ui/park_theme.dart';

class VehicleQrScreen extends StatefulWidget {
  final VehicleModel vehicle;
  final VehicleQrSource source;
  final ApiService? apiService;
  const VehicleQrScreen({
    super.key,
    required this.vehicle,
    required this.source,
    this.apiService,
  });
  @override
  State<VehicleQrScreen> createState() => _VehicleQrScreenState();
}

class _VehicleQrScreenState extends State<VehicleQrScreen> {
  VehicleQr? _qr;
  String? _error;
  bool _loading = true;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _qr != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _qr = null;
    });
    try {
      final qr = await widget.source.issue(widget.vehicle);
      if (qr.vehicleId != widget.vehicle.id || qr.token.isEmpty) {
        throw const ApiException('El QR recibido no corresponde al vehículo.');
      }
      if (mounted) setState(() => _qr = qr);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ApiException
              ? error.message
              : 'No se pudo cargar el QR. Intenta nuevamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final expired = _qr?.isExpired(DateTime.now().toUtc()) ?? false;
    final remaining = _qr == null
        ? Duration.zero
        : _qr!.expiresAt.difference(DateTime.now().toUtc());
    final seconds = remaining.inSeconds.clamp(0, 99999);
    final countdown =
        '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
    return ParkShell(
      api: widget.apiService,
      selected: 1,
      breadcrumb: 'QR del vehículo',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ParkHeading(
            'Tu pase de entrada',
            'Preséntalo en portería para validar tu vehículo.',
          ),
          ParkColumns(
            flex: const [5, 6],
            children: [
              ParkCard(
                child: Column(
                  children: [
                    ParkBadge(
                      _loading
                          ? 'Generando QR'
                          : expired
                          ? 'QR vencido'
                          : _error != null
                          ? 'QR no disponible'
                          : 'QR activo',
                      success: !_loading && !expired && _qr != null,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      widget.vehicle.plate,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'QR · ${widget.vehicle.plate}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      widget.vehicle.isMoto ? 'Moto' : 'Automóvil',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 28),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.all(50),
                        child: CircularProgressIndicator(),
                      )
                    else if (_error != null)
                      Text(_error!, textAlign: TextAlign.center)
                    else if (expired)
                      const Text('QR vencido. Genera uno nuevo.')
                    else if (_qr != null) ...[
                      Semantics(
                        label: 'QR del vehículo ${widget.vehicle.plate}',
                        child: QrImageView(
                          data: _qr!.token,
                          size: 220,
                          backgroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        'Vence en $countdown',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      const Text('Presenta este QR en portería.'),
                    ],
                    const SizedBox(height: 28),
                    if (widget.source.isDemo)
                      const Text(
                        'DEMOSTRACIÓN · No autoriza acceso real',
                        textAlign: TextAlign.center,
                      ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _loading ? null : _load,
                      child: const Text('Generar nuevo QR'),
                    ),
                  ],
                ),
              ),
              const ParkCard(
                color: ParkColors.yellow,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ParkIcon(Icons.directions_car_outlined),
                    SizedBox(height: 22),
                    Text(
                      'Seguro por diseño.',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 32),
                    Text(
                      'El QR es temporal y de un solo uso. El operador confirma el ingreso o la salida después de validarlo.',
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No compartas capturas de tu código.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 24),
                    ParkCar(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
