import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/api_service.dart';
import '../services/gate_service.dart';

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
    });
    try {
      if (raw.trim().isEmpty) {
        throw const ApiException('Escanea o introduce un QR.');
      }
      final preview = await widget.gateway.inspect(raw.trim());
      if (mounted) {
        setState(() {
          _preview = preview;
          _requestId = UniqueKey().toString();
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
      if (!DateTime.now().toUtc().isBefore(preview.expiresAt)) {
        throw const ApiException('QR vencido. Solicita uno nuevo.');
      }
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
        setState(
          () => _error = error is ApiException
              ? error.message
              : 'No se pudo confirmar. Reintenta la misma operación.',
        );
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Portería')),
    body: !_allowed
        ? const Center(child: Text('No tienes permiso para operar portería.'))
        : ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (widget.gateway.isDemo)
                const Text('DEMOSTRACIÓN · Sin acceso ni cobro real'),
              const SizedBox(height: 16),
              SegmentedButton<GateAction>(
                segments: const [
                  ButtonSegment(
                    value: GateAction.entry,
                    label: Text('Ingreso'),
                  ),
                  ButtonSegment(value: GateAction.exit, label: Text('Salida')),
                ],
                selected: {_action},
                onSelectionChanged: _busy || _preview != null
                    ? null
                    : (selection) => setState(() => _action = selection.first),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _busy || _preview != null ? null : _scan,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Escanear QR'),
              ),
              TextField(
                controller: _text,
                enabled: !_busy && _preview == null,
                decoration: const InputDecoration(
                  labelText: 'Código QR',
                  helperText: 'También puedes introducir el código con un lector externo.',
                ),
              ),
              TextButton(
                onPressed: _busy || _preview != null
                    ? null
                    : () => _inspect(_text.text),
                child: const Text('Validar código'),
              ),
              if (_busy) const Center(child: CircularProgressIndicator()),
              if (_error != null) Text(_error!, semanticsLabel: _error),
              if (_preview != null) ...[
                Text('Vehículo: ${_preview!.plate}'),
                Text(
                  'Operación: ${_action == GateAction.entry ? 'Ingreso' : 'Salida'}',
                ),
                const Text('Confirma los datos antes de registrar.'),
                FilledButton(
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
                        }),
                  child: const Text('Cancelar'),
                ),
              ],
              if (_receipt != null) Text(_receipt!),
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
