import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/user_model.dart';
import 'login_screen.dart';

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

  void _handleLogout() async {
    await widget.apiService.logout();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => LoginScreen(apiService: widget.apiService),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E17),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        title: const Row(
          children: [
            Icon(Icons.point_of_sale, color: Color(0xFFF59E0B)),
            SizedBox(width: 8),
            Text(
              'Taquilla Presencial USTA',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFFF87171)),
            onPressed: _handleLogout,
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner de Rol Autorizado
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A8A).withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.4),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.admin_panel_settings,
                    color: Color(0xFF3B82F6),
                    size: 24,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Módulo Exclusivo de Taquilla: Solo el operador autorizado puede ingresar abonos en efectivo al sistema.',
                      style: TextStyle(color: Color(0xFFBFDBFE), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFEF4444)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Color(0xFFEF4444),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Color(0xFFF87171),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const Text(
              'Conductor / Usuario Destinatario',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white24),
              ),
              child: _isLoadingUsers
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFF59E0B),
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  : DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _selectedUserId,
                        dropdownColor: const Color(0xFF111827),
                        style: const TextStyle(color: Colors.white),
                        isExpanded: true,
                        items: _users
                            .map(
                              (u) => DropdownMenuItem(
                                value: u.id,
                                child: Text(
                                  '${u.name} (Saldo actual: \$${u.balance})',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedUserId = val);
                          }
                        },
                      ),
                    ),
            ),
            const SizedBox(height: 18),

            const Text(
              'Punto de Atención Físico USTA',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white24),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedPoint,
                  dropdownColor: const Color(0xFF111827),
                  style: const TextStyle(color: Colors.white),
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(
                      value: 'Punto 1 - Portería Principal USTA',
                      child: Text(
                        'Punto 1 - Portería Principal (Entrada vehicular)',
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'Punto 2 - Cafetería Central USTA',
                      child: Text(
                        'Punto 2 - Cafetería Central (Edif. Santo Domingo)',
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedPoint = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 18),

            const Text(
              'Importe en Efectivo Recibido (COP) *',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                prefixText: '\$ ',
                prefixStyle: const TextStyle(
                  color: Color(0xFFF59E0B),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                hintText: '10000',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                ),
                filled: true,
                fillColor: const Color(0xFF111827),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.white24),
                ),
              ),
            ),
            const SizedBox(height: 10),

            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  label: const Text('\$4.000'),
                  onPressed: () => _amountController.text = '4000',
                  backgroundColor: const Color(
                    0xFF1E3A8A,
                  ).withValues(alpha: 0.4),
                  labelStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
                ActionChip(
                  label: const Text('\$5.000'),
                  onPressed: () => _amountController.text = '5000',
                  backgroundColor: const Color(
                    0xFF1E3A8A,
                  ).withValues(alpha: 0.4),
                  labelStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
                ActionChip(
                  label: const Text('\$20.000'),
                  onPressed: () => _amountController.text = '20000',
                  backgroundColor: const Color(
                    0xFF1E3A8A,
                  ).withValues(alpha: 0.4),
                  labelStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _handleRecharge,
                icon: const Icon(
                  Icons.check_circle_outline,
                  color: Color(0xFF0B0F19),
                ),
                label: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Text(
                        'Registrar Abono en Taquilla',
                        style: TextStyle(
                          color: Color(0xFF0B0F19),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Comprobante Digital generado
            if (_lastReceipt != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF10B981),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'COMPROBANTE DE RECARGA',
                          style: TextStyle(
                            color: Color(0xFF10B981),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          'ESTADO: EXITOSO',
                          style: TextStyle(
                            color: Color(0xFF10B981),
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white12, height: 16),
                    Text(
                      'Usuario: ${_lastReceipt!['user_name']}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      'Punto: ${_lastReceipt!['point_name']}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      'Referencia: ${_lastReceipt!['reference']}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      'Fecha: ${_lastReceipt!['created_at']}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Importe: + \$${_lastReceipt!['amount']} COP',
                          style: const TextStyle(
                            color: Color(0xFF10B981),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Nuevo Saldo: \$${_lastReceipt!['new_balance']} COP',
                          style: const TextStyle(
                            color: Color(0xFFF59E0B),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
