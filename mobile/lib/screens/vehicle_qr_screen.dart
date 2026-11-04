import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/vehicle_model.dart';
import '../services/api_service.dart';
import '../services/vehicle_qr_service.dart';

class VehicleQrScreen extends StatefulWidget {
  final VehicleModel vehicle;
  final VehicleQrSource source;
  const VehicleQrScreen({
    super.key,
    required this.vehicle,
    required this.source,
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
    return Scaffold(
      appBar: AppBar(title: Text('QR · ${widget.vehicle.plate}')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.source.isDemo)
                const Text(
                  'DEMOSTRACIÓN · No autoriza acceso real',
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 16),
              if (_loading)
                const CircularProgressIndicator()
              else if (_error != null)
                Text(_error!, textAlign: TextAlign.center)
              else if (expired)
                const Text('QR vencido. Genera uno nuevo.')
              else if (_qr != null) ...[
                Semantics(
                  label: 'QR del vehículo ${widget.vehicle.plate}',
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(16),
                    child: QrImageView(
                      data: _qr!.token,
                      size: 220,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Válido hasta ${_qr!.expiresAt.toLocal().toString().split('.').first}',
                ),
                const Text('Presenta este QR en portería.'),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Generar nuevo QR'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
