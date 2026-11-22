import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/gate_service.dart';
import '../ui/park_widgets.dart';
import 'visitor_receipt.dart';

class VisitorSaleForm extends StatefulWidget {
  final ApiService api;
  final bool enabled;
  final String pointName;
  final ValueChanged<bool> onBusy;
  final VoidCallback onSold;
  const VisitorSaleForm({
    super.key,
    required this.api,
    required this.enabled,
    required this.pointName,
    required this.onBusy,
    required this.onSold,
  });
  @override
  State<VisitorSaleForm> createState() => _VisitorSaleFormState();
}

class _VisitorSaleFormState extends State<VisitorSaleForm> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(), _plate = TextEditingController();
  String _type = 'automovil';
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _receipt;
  bool get _pending => widget.api.pendingVisitorSale != null;
  @override
  void initState() {
    super.initState();
    final draft = widget.api.pendingVisitorSale;
    if (draft != null) {
      _name.text = '${draft['visitor_name']}';
      _plate.text = '${draft['plate']}';
      _type = '${draft['vehicle_type']}';
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _plate.dispose();
    super.dispose();
  }

  Future<void> _sell() async {
    if (_busy ||
        (!_pending && (!widget.enabled || !_form.currentState!.validate())))
      return;
    setState(() {
      _busy = true;
      _error = null;
    });
    widget.onBusy(true);
    try {
      if (!_pending) {
        final quote = await widget.api.request(
          'GET',
          '/api/admin/visitor-passes/quote?vehicle_type=$_type',
        );
        if (!mounted) return;
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Confirmar pago recibido'),
            content: Text(
              'Pase diario de ${_plate.text.trim().toUpperCase()} para ${_name.text.trim()}.\nRecibido en efectivo: ${quote['amount']} COP.\nVálido el ${quote['service_date']} (Colombia).',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Recibí el efectivo · Generar QR'),
              ),
            ],
          ),
        );
        if (ok != true) return;
        widget.api.pendingVisitorSale = {
          'visitor_name': _name.text.trim(),
          'plate': _plate.text.trim().toUpperCase(),
          'vehicle_type': _type,
          'point_name': widget.pointName,
          'expected_amount': quote['amount'],
          'service_date': quote['service_date'],
          'request_id': newGateRequestId(),
        };
      }
      final data = await widget.api.request(
        'POST',
        '/api/admin/visitor-passes',
        widget.api.pendingVisitorSale!,
      );
      widget.api.pendingVisitorSale = null;
      if (mounted) {
        setState(() => _receipt = data['pass'] as Map<String, dynamic>);
        widget.onSold();
      }
    } catch (e) {
      if (e is ApiException && e.statusCode != null && e.statusCode! < 500)
        widget.api.pendingVisitorSale = null;
      if (mounted)
        setState(
          () => _error = _pending
              ? 'No llegó confirmación. Reintenta para recuperar el mismo pase sin cobrar dos veces.'
              : e.toString(),
        );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        widget.onBusy(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ParkCard(
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ParkIcon(Icons.confirmation_number_outlined),
              const SizedBox(height: 20),
              Text(
                'Pase diario visitante',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              const Text(
                'Para personas externas a la universidad. El efectivo se suma al mismo recaudo de esta caja.',
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _name,
                enabled: widget.enabled && !_busy && !_pending,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: 'Nombre del visitante',
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Escribe el nombre.' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _plate,
                enabled: widget.enabled && !_busy && !_pending,
                maxLength: 10,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Placa del vehículo',
                ),
                validator: (v) =>
                    RegExp(
                      r'^[A-Z0-9]{5,10}$',
                    ).hasMatch(v?.trim().toUpperCase() ?? '')
                    ? null
                    : 'Escribe una placa de 5 a 10 letras o números.',
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(
                  labelText: 'Tipo de vehículo',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'automovil',
                    child: Text('Automóvil'),
                  ),
                  DropdownMenuItem(value: 'moto', child: Text('Moto')),
                ],
                onChanged: widget.enabled && !_busy && !_pending
                    ? (v) => setState(() => _type = v!)
                    : null,
              ),
              const SizedBox(height: 16),
              Text('Punto de caja: ${widget.pointName}'),
              const SizedBox(height: 16),
              if (!widget.enabled && !_pending)
                const Text('Abre una caja para cobrar pases.'),
              if (_error != null) ParkNotice(_error!),
              FilledButton(
                onPressed: _busy || (!widget.enabled && !_pending)
                    ? null
                    : _sell,
                child: Text(
                  _busy
                      ? 'Procesando…'
                      : _pending
                      ? 'Reintentar emisión del pase'
                      : 'Cobrar pase y generar QR',
                ),
              ),
            ],
          ),
        ),
      ),
      if (_receipt != null) ...[
        const SizedBox(height: 20),
        VisitorReceipt(api: widget.api, receipt: _receipt!),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _busy
              ? null
              : () => setState(() {
                  _receipt = null;
                  _name.clear();
                  _plate.clear();
                }),
          child: const Text('Registrar otro visitante'),
        ),
      ],
    ],
  );
}
