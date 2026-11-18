import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';

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
  DailyQrQuote? _quote;
  bool get _daily => widget.source is DailyVehicleQrSource;
  String? _error;
  bool _loading = true;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    if (_daily) {
      _lookup();
    } else {
      _load();
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _qr != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _lookup() async {
    setState(() {
      _loading = true;
      _error = null;
      _qr = null;
      _quote = null;
    });
    try {
      final quote = await (widget.source as DailyVehicleQrSource).lookup(
        widget.vehicle,
      );
      if (mounted) {
        setState(() {
          _quote = quote;
          _qr = quote.qr;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ApiException
              ? error.message
              : 'No se pudo consultar el pase diario.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmGenerate() async {
    final quote = _quote;
    if (quote == null) return;
    final price = NumberFormat.decimalPattern('es_CO').format(quote.amount);
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generar QR diario'),
        content: Text(
          'Se descontarán $price COP de tu saldo por el pase de ${widget.vehicle.plate}. Será tu único QR de hoy y quedará vinculado a este vehículo. Consultarlo de nuevo no vuelve a cobrar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar y generar'),
          ),
        ],
      ),
    );
    if (accepted == true && mounted) await _load();
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
        if (error is ApiException &&
            ['PRICE_CHANGED', 'DAY_CHANGED'].contains(error.code)) {
          _quote = null;
        }
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
                          ? (_daily ? 'Consultando pase' : 'Generando QR')
                          : expired
                          ? 'QR vencido'
                          : _error != null
                          ? 'QR no disponible'
                          : (_daily
                                ? (_qr == null
                                      ? 'Pase pendiente'
                                      : 'QR diario activo')
                                : 'QR activo'),
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
                          data: _qr!.scanUrl ?? _qr!.token,
                          size: 220,
                          backgroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        _qr!.daily
                            ? 'Válido hasta medianoche · Colombia'
                            : 'Vence en $countdown',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      const Text('Presenta este QR en portería.'),
                      if (_qr!.daily) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Pase pagado: ${NumberFormat.decimalPattern('es_CO').format(_qr!.amount)} COP. Consultarlo no genera otro cobro.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Al escanearlo se muestran tu nombre, placa y tipo de vehículo.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                    if (_daily &&
                        _qr == null &&
                        !_loading &&
                        _quote != null) ...[
                      Text(
                        'Pase diario: ${NumberFormat.decimalPattern('es_CO').format(_quote!.amount)} COP',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'El cobro se realiza únicamente al confirmar la generación del QR.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 28),
                    if (widget.source.isDemo)
                      const Text(
                        'DEMOSTRACIÓN · No autoriza acceso real',
                        textAlign: TextAlign.center,
                      ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _loading
                          ? null
                          : !_daily
                          ? _load
                          : _qr != null || _quote == null
                          ? _lookup
                          : _confirmGenerate,
                      child: Text(
                        !_daily
                            ? 'Generar nuevo QR'
                            : _qr != null
                            ? 'Consultar QR de hoy'
                            : _quote == null
                            ? 'Consultar pase diario'
                            : 'Generar QR diario',
                      ),
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
                      'Un pase por usuario y día. Se cobra al generar el QR según tu vehículo. Podrás consultar el mismo código hasta medianoche, sin volver a pagar.',
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
