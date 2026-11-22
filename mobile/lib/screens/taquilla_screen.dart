import 'package:flutter/material.dart';

import 'dart:async';

import '../widgets/visitor_sale_form.dart';
import '../services/api_service.dart';
import '../widgets/cash_session_card.dart';
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
  bool _isLoadingUsers = false;
  bool _visitor = false;
  final _search = TextEditingController();
  Timer? _debounce;
  int _searchVersion = 0;
  bool _isSubmitting = false;
  String? _errorMessage;
  Map<String, dynamic>? _lastReceipt;
  int _cashVersion = 0;
  bool _cashBusy = false;
  Map<String, dynamic>? _cashSession;
  bool get _canRecharge => _cashSession?['can_recharge'] == true;

  @override
  void initState() {
    super.initState();
    _visitor = widget.apiService.pendingVisitorSale != null;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    final query = _search.text.trim();
    final version = ++_searchVersion;
    if (query.length < 2) {
      setState(() {
        _users = [];
        _isLoadingUsers = false;
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _isLoadingUsers = true;
      _errorMessage = null;
    });
    try {
      final list = await widget.apiService.getUsers(search: query);
      if (!mounted || version != _searchVersion) return;
      setState(() {
        _users = list.where((u) => u.role != 'operador').toList();
        if (!_users.any((u) => u.id == _selectedUserId)) {
          _selectedUserId = null;
        }
        _isLoadingUsers = false;
      });
    } on ApiException catch (e) {
      if (!mounted || version != _searchVersion) return;
      setState(() {
        _errorMessage = e.message;
        _isLoadingUsers = false;
      });
    }
  }

  Future<void> _handleRecharge() async {
    if (!_canRecharge || _cashBusy) return;
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
        _cashVersion++;
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
      setState(() => _cashVersion++);
      _fetchUsers();
    },
    busy: _isSubmitting || _cashBusy,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ParkHeading(
          'Centro de operaciones',
          'Gestiona recargas presenciales y consulta la actividad de taquilla.',
        ),
        CashSessionCard(
          api: widget.apiService,
          version: _cashVersion,
          disabled: _isSubmitting,
          onBusy: (busy) => setState(() => _cashBusy = busy),
          onSession: (session) => setState(() {
            _cashSession = session;
            if (session != null) {
              _selectedPoint = session['point_name'] as String;
            }
          }),
        ),
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: ParkColors.ink),
            onPressed: _isSubmitting || _cashBusy
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
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Recarga usuario'),
              selected: !_visitor,
              onSelected:
                  _isSubmitting ||
                      _cashBusy ||
                      widget.apiService.pendingVisitorSale != null
                  ? null
                  : (v) => setState(() => _visitor = false),
            ),
            ChoiceChip(
              label: const Text('Pase diario visitante'),
              selected: _visitor,
              onSelected: _isSubmitting || _cashBusy
                  ? null
                  : (v) => setState(() => _visitor = true),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (_visitor)
          VisitorSaleForm(
            api: widget.apiService,
            enabled: _canRecharge && !_cashBusy,
            pointName: _selectedPoint,
            onBusy: (v) => setState(() => _isSubmitting = v),
            onSold: () => setState(() => _cashVersion++),
          )
        else
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
                    TextField(
                      controller: _search,
                      enabled: !_isSubmitting && !_cashBusy,
                      decoration: const InputDecoration(
                        labelText:
                            'Buscar usuario por nombre, documento o correo',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) {
                        _debounce?.cancel();
                        _searchVersion++;
                        setState(() {
                          _selectedUserId = null;
                          _users = [];
                          _isLoadingUsers = false;
                        });
                        _debounce = Timer(
                          const Duration(milliseconds: 350),
                          _fetchUsers,
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    if (_isLoadingUsers)
                      const LinearProgressIndicator()
                    else if (_search.text.trim().length < 2)
                      const Text('Escribe al menos 2 caracteres para buscar.')
                    else if (_users.isEmpty)
                      const Text('No se encontraron usuarios.')
                    else
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 260),
                        child: ListView(
                          shrinkWrap: true,
                          children: [
                            for (final user in _users)
                              ListTile(
                                selected: _selectedUserId == user.id,
                                selectedTileColor: ParkColors.yellow.withValues(
                                  alpha: .25,
                                ),
                                title: Text(user.name),
                                subtitle: Text(
                                  '${user.email}${user.documentNumber == null ? '' : ' · ${user.documentType} ${user.documentNumber}'}',
                                ),
                                trailing: _selectedUserId == user.id
                                    ? const Icon(Icons.check_circle_outline)
                                    : null,
                                onTap:
                                    _isSubmitting || _cashBusy || !_canRecharge
                                    ? null
                                    : () => setState(
                                        () => _selectedUserId = user.id,
                                      ),
                              ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 18),
                    Text(
                      _canRecharge
                          ? 'Punto de caja: $_selectedPoint'
                          : 'Abre una caja para registrar recargas.',
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _amountController,
                      enabled: !_isSubmitting && !_cashBusy && _canRecharge,
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
                            onPressed:
                                _isSubmitting || _cashBusy || !_canRecharge
                                ? null
                                : () => _amountController.text = amount
                                      .toString(),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed:
                          _isSubmitting ||
                              _cashBusy ||
                              !_canRecharge ||
                              _isLoadingUsers ||
                              _selectedUserId == null
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
      ],
    ),
  );
}
