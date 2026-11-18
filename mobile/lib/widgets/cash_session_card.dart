import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';
import '../ui/park_widgets.dart';
import '../ui/park_theme.dart';

class CashSessionCard extends StatefulWidget {
  final ApiService api;
  final int version;
  final bool disabled;
  final ValueChanged<Map<String, dynamic>?> onSession;
  final ValueChanged<bool> onBusy;
  const CashSessionCard({
    super.key,
    required this.api,
    required this.onSession,
    required this.onBusy,
    this.version = 0,
    this.disabled = false,
  });
  @override
  State<CashSessionCard> createState() => _CashSessionCardState();
}

class _CashSessionCardState extends State<CashSessionCard> {
  final _base = TextEditingController();
  final _counted = TextEditingController();
  final _retained = TextEditingController();
  final _notes = TextEditingController();
  final _money = NumberFormat.decimalPattern('es_CO');
  Map<String, dynamic>? _session;
  List<Map<String, dynamic>> _points = [];
  String? _point;
  String? _error;
  String? _notice;
  bool _loading = true;
  bool _busy = false;
  bool _showClose = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant CashSessionCard old) {
    super.didUpdateWidget(old);
    if (old.version != widget.version) _load();
  }

  @override
  void dispose() {
    for (final c in [_base, _counted, _retained, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic>? get _selected =>
      _points.where((p) => p['point_name'] == _point).firstOrNull;
  Future<void> _load() async {
    try {
      final data = await widget.api.request('GET', '/api/cash/current');
      if (!mounted) return;
      setState(() {
        _error = null;
        _loading = false;
        _session = data['session'] as Map<String, dynamic>?;
        _points = (data['points'] as List).cast<Map<String, dynamic>>();
        _point ??= _points.firstOrNull?['point_name'] as String?;
        _setBase();
      });
      widget.onSession(_session);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
        widget.onSession(null);
      }
    }
  }

  void _setBase() {
    if (_selected?['carried'] == true) {
      _base.text = '${_selected?['opening_amount'] ?? 0}';
    }
  }

  Widget _amount(
    TextEditingController controller,
    String label, {
    bool enabled = true,
  }) => TextField(
    controller: controller,
    enabled: enabled && !_busy && !widget.disabled,
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    decoration: InputDecoration(labelText: label, suffixText: 'COP'),
  );
  Future<void> _submit(bool closing) async {
    final base = int.tryParse(_base.text);
    final counted = int.tryParse(_counted.text),
        retained = int.tryParse(_retained.text);
    if ((!closing && (base == null || base < 0 || base > 1000000000000)) ||
        (closing &&
            (counted == null ||
                retained == null ||
                counted < 0 ||
                retained < 0 ||
                counted > 1000000000000 ||
                retained > counted))) {
      setState(
        () => _error =
            'Ingresa importes enteros válidos. La base retenida no puede superar lo contado.',
      );
      return;
    }
    final expected = (_session?['expected_cash'] as num?)?.toInt() ?? 0;
    if (closing && counted != expected && _notes.text.trim().isEmpty) {
      setState(
        () => _error = 'Explica el faltante o sobrante antes de cerrar.',
      );
      return;
    }
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          closing ? 'Confirmar cierre de caja' : 'Confirmar apertura',
        ),
        content: Text(
          closing
              ? 'Contado: ${_money.format(counted)} COP\nBase para devueltas: ${_money.format(retained)} COP\nA entregar: ${_money.format(counted! - retained!)} COP\nDiferencia: ${_money.format(counted - expected)} COP\n\nEl cierre es definitivo. No podrás registrar más recargas en este punto hoy.'
              : 'Se registrará una base de ${_money.format(base)} COP en $_point.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    widget.onBusy(true);
    try {
      await widget.api.request(
        'POST',
        closing ? '/api/cash/${_session!['id']}/close' : '/api/cash/open',
        closing
            ? {
                'counted_cash': counted,
                'retained_cash': retained,
                'notes': _notes.text.trim(),
              }
            : {'point_name': _point, 'opening_amount': base},
      );
      if (!mounted) return;
      _notice = closing
          ? 'Cierre registrado. El comprobante está en Reportes.'
          : 'Caja abierta. Ya puedes registrar recargas.';
      _showClose = false;
      _counted.clear();
      _retained.clear();
      _notes.clear();
      await _load();
    } catch (e) {
      if (mounted) {
        setState(
          () => _error =
              '$e Actualiza el panel antes de reintentar; si el cierre ya se guardó, estará en Reportes.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        widget.onBusy(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => ParkCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Apertura y cierre de caja',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            TextButton.icon(
              onPressed: _busy || widget.disabled ? null : _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Actualizar caja'),
            ),
          ],
        ),
        if (_loading) const LinearProgressIndicator(),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: ParkNotice(_error!, retry: _busy ? null : _load),
          ),
        if (_notice != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(_notice!),
          ),
        if (!_loading && _session == null) ...[
          const Text('Caja cerrada · Abre el día antes de recibir efectivo.'),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _point,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Punto de caja'),
            items: [
              for (final p in _points)
                DropdownMenuItem(
                  value: p['point_name'] as String,
                  child: Text(p['point_name'] as String, maxLines: 2),
                ),
            ],
            onChanged: _busy || widget.disabled
                ? null
                : (v) => setState(() {
                    _point = v;
                    _base.clear();
                    _setBase();
                  }),
          ),
          const SizedBox(height: 16),
          if (_selected?['available'] == true) ...[
            _amount(
              _base,
              'Base de apertura para devueltas',
              enabled: _selected?['carried'] != true,
            ),
            const SizedBox(height: 12),
            Text(
              _selected?['carried'] == true
                  ? 'Base heredada del último cierre de este punto.'
                  : 'Primera apertura: registra el efectivo inicial para devueltas.',
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy || widget.disabled ? null : () => _submit(false),
              icon: const Icon(Icons.lock_open),
              label: Text(_busy ? 'Registrando…' : 'Abrir caja'),
            ),
          ] else
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Text(
                'Este punto ya se cerró hoy o tiene una caja abierta. Selecciona otro punto o vuelve el día siguiente.',
              ),
            ),
        ],
        if (_session != null) ...[
          ParkBadge(
            'Caja abierta · ${_session!['business_date']}',
            success: true,
          ),
          const SizedBox(height: 16),
          Text('${_session!['point_name']}'),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _metric('Base inicial', _session!['opening_amount']),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _metric(
                  'Recargas en efectivo',
                  _session!['recharge_total'],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _metric('Efectivo esperado', _session!['expected_cash']),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_session!['can_recharge'] != true)
            const ParkNotice(
              'Esta caja corresponde al día anterior. Ciérrala y abre la de hoy para seguir recargando.',
            ),
          TextButton.icon(
            onPressed: _busy || widget.disabled
                ? null
                : () => setState(() => _showClose = !_showClose),
            icon: const Icon(Icons.lock_outline),
            label: Text(
              _showClose ? 'Ocultar cierre' : 'Preparar cierre de caja',
            ),
          ),
          if (_showClose) ...[
            const Text(
              'Al finalizar, cuenta todo el efectivo, incluida la base inicial. El dinero para devueltas quedará reservado para la siguiente apertura.',
            ),
            const SizedBox(height: 16),
            ParkColumns(
              children: [
                _amount(_counted, 'Efectivo total contado'),
                _amount(_retained, 'Base que queda para devueltas'),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notes,
              enabled: !_busy && !widget.disabled,
              maxLength: 1000,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Observaciones / motivo de diferencia',
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: ParkColors.ink),
              onPressed: _busy || widget.disabled ? null : () => _submit(true),
              icon: const Icon(Icons.lock_outline),
              label: Text(
                _busy ? 'Registrando…' : 'Cerrar caja y generar comprobante',
              ),
            ),
          ],
        ],
      ],
    ),
  );
  Widget _metric(String label, dynamic value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label),
      const SizedBox(height: 6),
      FittedBox(
        child: Text(
          '${_money.format(value)} COP',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 22),
        ),
      ),
    ],
  );
}
