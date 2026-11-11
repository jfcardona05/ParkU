import '../widgets/load_error.dart';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../models/vehicle_model.dart';
import '../models/transaction_model.dart';
import '../widgets/balance_card.dart';
import '../widgets/license_plate_widget.dart';
import '../widgets/wallet_movement_tile.dart';
import 'vehicles_screen.dart';
import 'wallet_screen.dart';
import 'login_screen.dart';
import 'parking_screen.dart';

class DashboardScreen extends StatefulWidget {
  final ApiService apiService;

  const DashboardScreen({super.key, required this.apiService});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  int _refreshVersion = 0;
  String? _loadError;
  bool _isLoading = true;
  int _balance = 0;
  List<VehicleModel> _vehicles = [];
  List<TransactionModel> _recentTx = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final bal = await widget.apiService.getBalance();
      final vehs = await widget.apiService.getVehicles();
      final txs = await widget.apiService.getHistory();
      if (!mounted) return;
      setState(() {
        _balance = bal;
        _vehicles = vehs;
        _recentTx = txs;
        _refreshVersion++;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _isLoading = false;
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
    final user = widget.apiService.currentUser;

    final pages = [
      _buildHomeTab(user?.name ?? 'Usuario'),
      WalletScreen(
        key: ValueKey(_refreshVersion),
        apiService: widget.apiService,
      ),
      VehiclesScreen(apiService: widget.apiService),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E17),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A8A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFF59E0B)),
              ),
              child: const Center(
                child: Text(
                  'P',
                  style: TextStyle(
                    color: Color(0xFFF59E0B),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'ParkU',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _loadData,
            tooltip: 'Actualizar',
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFFF87171)),
            onPressed: _handleLogout,
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
          if (index == 0) _loadData();
        },
        backgroundColor: const Color(0xFF111827),
        selectedItemColor: const Color(0xFFF59E0B),
        unselectedItemColor: Colors.white38,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            activeIcon: Icon(Icons.account_balance_wallet),
            label: 'Saldo',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_car_outlined),
            activeIcon: Icon(Icons.directions_car),
            label: 'Vehículos',
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTab(String userName) {
    if (_loadError != null) {
      return LoadError(message: _loadError!, retry: _loadData);
    }
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFF59E0B)),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFFF59E0B),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hola, ${userName.split(' ')[0]} 👋',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Text(
              'Campus Universidad Santo Tomás',
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
            ),
            const SizedBox(height: 16),

            // Tarjeta de Saldo (HU-01 y HU-02)
            BalanceCard(balance: _balance),
            const SizedBox(height: 16),

            OutlinedButton.icon(
              icon: const Icon(Icons.local_parking),
              label: const Text('Consultar cupos, tarifas y accesos'),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ParkingScreen(apiService: widget.apiService),
                  ),
                );
                await _loadData();
              },
            ),
            const SizedBox(height: 20),

            // Vehículo Principal (HU-06)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Mis Vehículos Asociados',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _currentIndex = 2),
                  child: Text(
                    'Ver todos (${_vehicles.length})',
                    style: const TextStyle(
                      color: Color(0xFFF59E0B),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (_vehicles.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  children: [
                    const Text(
                      'No tienes vehículos registrados en tu cuenta.',
                      style: TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => setState(() => _currentIndex = 2),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                      ),
                      child: const Text(
                        'Registrar Vehículo (HU-06)',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    Icon(
                      _vehicles[0].isMoto
                          ? Icons.two_wheeler
                          : Icons.directions_car,
                      color: const Color(0xFF3B82F6),
                      size: 32,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LicensePlateWidget(
                            plate: _vehicles[0].plate,
                            fontSize: 14,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _vehicles[0].brandModel.isNotEmpty
                                ? _vehicles[0].brandModel
                                : 'Vehículo activo',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Activo',
                        style: TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),
            const Text(
              'Últimos movimientos',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            if (_recentTx.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Aún no tienes movimientos registrados.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              )
            else
              for (final movement in _recentTx.take(3))
                WalletMovementTile(movement: movement),
          ],
        ),
      ),
    );
  }
}
