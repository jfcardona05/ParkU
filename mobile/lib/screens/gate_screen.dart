import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/api_service.dart';
import '../services/gate_service.dart';
import 'login_screen.dart';
import '../ui/park_shell.dart';
import '../ui/park_widgets.dart';
import '../ui/park_theme.dart';
import '../ui/park_glyph.dart';

class GateScreen extends StatefulWidget {
  final ApiService apiService;
  final GateGateway gateway;
  const GateScreen({
    super.key,
    required this.apiService,
    required this.gateway,
  });
  @override
  State<GateScreen> createState() => _GateScreenState();
}

class _GateScreenState extends State<GateScreen> {
  final _text = TextEditingController();
  GatePreview? _preview;
  GateAction _action = GateAction.entry;
  String? _error;
  String? _receipt;
  String? _requestId;
  bool _busy = false;
  bool _confirmationAttempted = false;
  bool get _allowed =>
      widget.gateway.isDemo ||
      ['guard', 'admin'].contains(widget.apiService.currentUser?.role);
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _inspect(String raw) async {
    if (_busy || !_allowed) return;
    setState(() {
      _busy = true;
      _preview = null;
      _receipt = null;
      _error = null;
      _requestId = null;
      _confirmationAttempted = false;
    });
    try {
      if (raw.trim().isEmpty) {
        throw const ApiException('Escanea o introduce un QR.');
      }
      final preview = await widget.gateway.inspect(raw.trim());
      if (mounted) {
        setState(() {
          _preview = preview;
          _action = preview.allowedAction ?? _action;
          _requestId = newGateRequestId();
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ApiException
              ? error.message
              : 'No se pudo validar el QR. Intenta nuevamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() async {
    if (_busy || !_allowed || _preview == null) return;
    final preview = _preview!;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!_confirmationAttempted &&
          !DateTime.now().toUtc().isBefore(preview.expiresAt)) {
        throw const ApiException('QR vencido. Solicita uno nuevo.');
      }
      _confirmationAttempted = true;
      final receipt = await widget.gateway.confirm(
        preview,
        _action,
        _requestId!,
      );
      if (mounted) {
        setState(() {
          _receipt = receipt;
          _preview = null;
          _text.clear();
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error is ApiException
              ? error.message
              : 'No se pudo confirmar. Reintenta la misma operación.';
          if (error is ApiException &&
              [
                'QR_EXPIRED',
                'QR_USED',
                'QR_REVOKED',
                'QR_INVALID',
              ].contains(error.code)) {
            _preview = null;
            _requestId = null;
            _confirmationAttempted = false;
          }
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _scan() async {
    final raw = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const _CameraScreen()),
    );
    if (mounted && raw != null) {
      _text.text = raw;
      await _inspect(raw);
    }
  }

  Future<void> _logout() async {
    await widget.apiService.logout();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => LoginScreen(apiService: widget.apiService),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ParkShell(
    api: widget.apiService,
    selected: 4,
    breadcrumb: 'Portería',
    busy: _busy,
    child: !_allowed
        ? ParkNotice('No tienes permiso para operar portería.', retry: _logout)
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ParkHeading(
                'Control de acceso',
                'Valida el QR antes de confirmar la operación.',
              ),
              if (widget.gateway.isDemo)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text('DEMOSTRACIÓN · Sin acceso ni cobro real'),
                ),
              ParkColumns(
                children: [
                  ParkCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SegmentedButton<GateAction>(
                          segments: const [
                            ButtonSegment(
                              value: GateAction.entry,
                              label: Text('Ingreso'),
                            ),
                            ButtonSegment(
                              value: GateAction.exit,
                              label: Text('Salida'),
                            ),
                          ],
                          selected: {_action},
                          style: ButtonStyle(
                            backgroundColor: WidgetStateProperty.resolveWith(
                              (states) => states.contains(WidgetState.selected)
                                  ? ParkColors.yellow
                                  : Colors.white,
                            ),
                            foregroundColor: const WidgetStatePropertyAll(
                              ParkColors.ink,
                            ),
                          ),
                          onSelectionChanged: _busy || _preview != null
                              ? null
                              : (selection) =>
                                    setState(() => _action = selection.first),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          height: 210,
                          decoration: BoxDecoration(
                            color: ParkColors.ink,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ParkGlyph(
                                Icons.qr_code_scanner,
                                size: MediaQuery.sizeOf(context).width >= 1100 ? 140 : 68,
                              ),
                              const SizedBox(height: 18),
                              const Text(
                                'Centra el QR del vehículo',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: FilledButton.icon(
                            onPressed: _busy || _preview != null ? null : _scan,
                            icon: const Icon(
                              Icons.camera_alt_outlined,
                              size: 18,
                            ),
                            label: const Text('Abrir cámara'),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'También puedes pegar el código QR',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _text,
                          enabled: !_busy && _preview == null,
                          decoration: const InputDecoration(
                            labelText: 'Código QR',
                            hintText: 'Pegar código…',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _busy || _preview != null
                              ? null
                              : () => _inspect(_text.text),
                          child: const Text('Validar código'),
                        ),
                        if (_busy)
                          const Center(child: CircularProgressIndicator()),
                      ],
                    ),
                  ),
                  ParkCard(
                    color: ParkColors.yellow,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const ParkIcon(Icons.sensor_door_outlined),
                        const SizedBox(height: 18),
                        ParkBadge(
                          _preview == null
                              ? 'Pendiente de validación'
                              : 'Vehículo validado',
                          success: _preview != null,
                        ),
                        const SizedBox(height: 24),
                        if (_error != null) ...[
                          Text(
                            _error!,
                            semanticsLabel: _error,
                            style: const TextStyle(color: Color(0xFF8C211B)),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (_preview != null) ...[
                          Text(
                            'Vehículo: ${_preview!.plate}',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Operación: ${_action == GateAction.entry ? 'Ingreso' : 'Salida'}',
                          ),
                          const SizedBox(height: 16),
                          const Text('Confirma los datos antes de registrar.'),
                          const SizedBox(height: 18),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                            ),
                            onPressed: _busy ? null : _confirm,
                            child: const Text('Confirmar operación'),
                          ),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => setState(() {
                                    _preview = null;
                                    _requestId = null;
                                    _error = null;
                                    _confirmationAttempted = false;
                                  }),
                            child: const Text('Cancelar'),
                          ),
                        ] else if (_receipt != null)
                          Text(
                            _receipt!,
                            style: Theme.of(context).textTheme.titleMedium,
                          )
                        else ...[
                          Text(
                            'Cada acceso,\nconfirmado.',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'Escanea o pega el código. Aquí verás el vehículo y la operación que autoriza el servidor.',
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
  );
}

class _CameraScreen extends StatefulWidget {
  const _CameraScreen();
  @override
  State<_CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<_CameraScreen> {
  final _controller = MobileScannerController(formats: [BarcodeFormat.qrCode]);
  bool _returned = false;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Escanear QR')),
    body: MobileScanner(
      controller: _controller,
      errorBuilder: (context, error) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No se pudo abrir la cámara. Revisa el permiso en el navegador o dispositivo. Puedes volver e introducir el código.',
          ),
        ),
      ),
      onDetect: (capture) {
        if (_returned) return;
        for (final barcode in capture.barcodes) {
          final value = barcode.rawValue;
          if (value != null && value.trim().isNotEmpty) {
            _returned = true;
            Navigator.pop(context, value);
            break;
          }
        }
      },
    ),
  );
}
