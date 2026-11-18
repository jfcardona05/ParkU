import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/recharge_history_card.dart';
import '../models/user_model.dart';
import '../ui/park_shell.dart';
import '../ui/park_widgets.dart';
import '../ui/park_theme.dart';
import 'gate_screen.dart';
import '../services/gate_service.dart';

class TaquillaScreen extends StatefulWidget {
  final ApiService apiService;

  const TaquillaScreen({super.key, required this.apiService});

  @override
  State<TaquillaScreen> createState() => _TaquillaScreenState();
}

class _TaquillaScreenState extends State<TaquillaScreen> {
  final _amountController = TextEditingController();
  String _selectedPoint = 'Punto 1 - Portería Principal USTA';
  int? _selectedUserId;
  List<UserModel> _users = [];
  bool _isLoadingUsers = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  Map<String, dynamic>? _lastReceipt;
  int _historyVersion = 0;
  final _historyKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    if (!mounted) return;
    setState(() {
      _isLoadingUsers = true;
      _errorMessage = null;
    });
    try {
      final list = await widget.apiService.getUsers();
      if (!mounted) return;
      setState(() {
        _users = list.where((u) => u.role != 'operador').toList();
        if (!_users.any((u) => u.id == _selectedUserId)) {
          _selectedUserId = _users.isEmpty ? null : _users.first.id;
        }
        _isLoadingUsers = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isLoadingUsers = false;
      });
    }
  }

  Future<void> _handleRecharge() async {
    if (_selectedUserId == null) {
      setState(
        () => _errorMessage = 'Debe seleccionar un usuario destinatario.',
      );
      return;
    }

    final amountText = _amountController.text.trim();
    final amount = int.tryParse(amountText);

    // Criterio 2 HU-02: Rechazo ante valores <= 0
    if (amount == null || amount <= 0) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Recarga rechazada: El importe debe ser mayor a \$0.';
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final res = await widget.apiService.recharge(
      amount: amount,
      pointName: _selectedPoint,
      userId: _selectedUserId,
    );

    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
    });

    if (res['success'] == true) {
      if (!mounted) return;
      setState(() {
        _lastReceipt = res['recharge'];
        _historyVersion++;
        _amountController.clear();
      });
      _fetchUsers(); // Actualizar saldo del usuario
    } else {
      if (!mounted) return;
      setState(() {
        _errorMessage = res['message'] ?? 'Error al procesar la recarga.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => ParkShell(
    api: widget.apiService,
    selected: 5,
    breadcrumb: 'Panel de caja',
    refresh: () {
      setState(() => _historyVersion++);
      _fetchUsers();
    },
    busy: _isSubmitting,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ParkHeading(
          'Centro de operaciones',
          'Gestiona recargas presenciales y consulta la actividad de taquilla.',
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              final target = _historyKey.currentContext;
              if (target != null) {
                Scrollable.ensureVisible(
                  target,
                  duration: const Duration(milliseconds: 300),
                );
              }
            },
            icon: const Icon(Icons.receipt_long_outlined),
            label: const Text('Ver historial de recargas'),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: ParkColors.ink),
            onPressed: _isSubmitting
                ? null
                : () => ParkShell.open(context, widget.apiService, 6),
            icon: const Icon(Icons.insights_outlined),
            label: const Text('Abrir reportes de caja'),
          ),
        ),
        const SizedBox(height: 12),
        if (const bool.fromEnvironment('PARKU_QR_DEMO'))
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GateScreen(
                  apiService: widget.apiService,
                  gateway: DemoGateGateway(),
                ),
              ),
            ),
            child: const Text('Demo portería'),
          ),
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: ParkNotice(
              _errorMessage!,
              retry: _isSubmitting ? null : _fetchUsers,
            ),
          ),
        ParkColumns(
          flex: const [6, 5],
          children: [
            ParkCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const ParkIcon(Icons.point_of_sale_outlined),
                  const SizedBox(height: 20),
                  Text(
                    'Recarga presencial',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 24),
                  if (_isLoadingUsers)
                    const Center(child: CircularProgressIndicator())
                  else if (_users.isEmpty)
                    const Text('No hay usuarios disponibles.')
                  else
                    DropdownButtonFormField<int>(
                      key: ValueKey(_selectedUserId),
                      initialValue: _selectedUserId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Usuario destinatario',
                      ),
                      items: [
                        for (final user in _users)
                          DropdownMenuItem(
                            value: user.id,
                            child: Text(
                              '${user.name} · ${user.email}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: _isSubmitting
                          ? null
                          : (value) => setState(() => _selectedUserId = value),
                    ),
                  const SizedBox(height: 18),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedPoint,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Punto físico de atención',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Punto 1 - Portería Principal USTA',
                        child: Text('Portería Principal'),
                      ),
                      DropdownMenuItem(
                        value: 'Punto 2 - Cafetería Central USTA',
                        child: Text('Cafetería Central'),
                      ),
                    ],
                    onChanged: _isSubmitting
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => _selectedPoint = value);
                            }
                          },
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _amountController,
                    enabled: !_isSubmitting,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Importe recibido en efectivo (COP)',
                      prefixText: '\$ ',
                      hintText: '10000',
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final amount in [4000, 5000, 20000])
                        ActionChip(
                          label: Text('\$$amount'),
                          onPressed: _isSubmitting
                              ? null
                              : () =>
                                    _amountController.text = amount.toString(),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed:
                        _isSubmitting || _isLoadingUsers || _users.isEmpty
                        ? null
                        : _handleRecharge,
                    child: Text(
                      _isSubmitting
                          ? 'Registrando…'
                          : 'Registrar abono en taquilla',
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const ParkCard(
                  color: ParkColors.yellow,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ParkIcon(Icons.account_balance_wallet_outlined),
                      SizedBox(height: 24),
                      Text(
                        'Cada abono,\ncon su comprobante.',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 20),
                      Text(
                        'Confirma el destinatario y el efectivo recibido. La recarga se refleja en el saldo y los movimientos del usuario.',
                      ),
                      SizedBox(height: 24),
                      ParkBadge('Solo operador autorizado'),
                    ],
                  ),
                ),
                if (_lastReceipt != null) ...[
                  const SizedBox(height: 20),
                  ParkCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const ParkBadge('Recarga registrada', success: true),
                        const SizedBox(height: 20),
                        Text(
                          'Comprobante de recarga',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        Text('Importe: +\$${_lastReceipt!['amount']} COP'),
                        Text(
                          'Saldo posterior: \$${_lastReceipt!['balance_after']} COP',
                        ),
                        const SizedBox(height: 12),
                        Text('Punto: ${_lastReceipt!['point_name']}'),
                        Text('Referencia: ${_lastReceipt!['reference']}'),
                        Text('Fecha: ${_lastReceipt!['created_at']}'),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
        RechargeHistoryCard(
          key: _historyKey,
          api: widget.apiService,
          refreshVersion: _historyVersion,
        ),
      ],
    ),
  );
}
