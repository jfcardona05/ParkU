import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/gate_service.dart';
import '../screens/dashboard_screen.dart';
import '../screens/vehicles_screen.dart';
import '../screens/wallet_screen.dart';
import '../screens/parking_screen.dart';
import '../screens/gate_screen.dart';
import '../screens/taquilla_screen.dart';
import '../screens/login_screen.dart';
import 'park_theme.dart';
import 'park_glyph.dart';

class ParkShell extends StatelessWidget {
  final ApiService? api;
  final int selected;
  final String breadcrumb;
  final Widget child;
  final bool scroll;
  final VoidCallback? refresh;
  final bool busy;
  const ParkShell({
    super.key,
    this.api,
    required this.selected,
    required this.breadcrumb,
    required this.child,
    this.scroll = true,
    this.refresh,
    this.busy = false,
  });

  static void open(BuildContext context, ApiService api, int index) {
    if (api.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inicia sesión para continuar.')),
      );
      return;
    }
    final Widget page = switch (index) {
      0 => DashboardScreen(apiService: api),
      1 => VehiclesScreen(apiService: api),
      2 => WalletScreen(apiService: api),
      3 => ParkingScreen(apiService: api),
      4 => GateScreen(apiService: api, gateway: ApiGateGateway(api)),
      _ => TaquillaScreen(apiService: api),
    };
    Navigator.of(
      context,
    ).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => page), (_) => false);
  }

  Future<void> _logout(BuildContext context) async {
    final service = api;
    if (service == null) return;
    await service.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => LoginScreen(apiService: service)),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final desktop = width >= 1100;
    final rail = width >= 768;
    final role = api?.currentUser?.role;
    final roleName = switch (role) {
      'guard' => 'Portería',
      'admin' => 'Administración',
      'operador' => 'Taquilla',
      _ => 'Usuario',
    };
    final items = <(int, IconData, String)>[
      (0, Icons.home_outlined, 'Inicio'),
      (1, Icons.directions_car_outlined, 'Vehículos'),
      (2, Icons.account_balance_wallet_outlined, 'Mi saldo'),
      (3, Icons.local_parking_outlined, 'Parqueadero'),
      if (role == 'guard' || role == 'admin')
        (4, Icons.sensor_door_outlined, 'Portería'),
      if (role == 'operador') (5, Icons.point_of_sale_outlined, 'Taquilla'),
    ];
    final name = api?.currentUser?.name ?? '';
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .take(2)
        .map((s) => s[0])
        .join()
        .toUpperCase();
    Widget logo() => const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: ParkColors.yellow,
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 7, vertical: 7),
            child: Text(
              'P',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ),
        ),
        SizedBox(width: 7),
        Text(
          'ParkU',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
      ],
    );
    Widget nav((int, IconData, String) item, {bool compact = false}) => Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Tooltip(
        message: compact ? item.$3 : '',
        child: Material(
          color: selected == item.$1 ? ParkColors.yellow : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: busy || api == null
                ? null
                : () => open(context, api!, item.$1),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ParkGlyph(item.$2, size: 22),
                  if (!compact) ...[
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        item.$3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
    final content = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1320),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          desktop ? 36 : 24,
          rail ? 0 : 12,
          desktop ? 36 : 24,
          32,
        ),
        child: child,
      ),
    );
    return Scaffold(
      backgroundColor: ParkColors.background,
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (rail)
              Container(
                width: desktop ? 236 : 88,
                color: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: desktop ? 24 : 16,
                  vertical: 24,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (desktop)
                        logo()
                      else
                        const Center(
                          child: Text(
                            'P',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 26,
                            ),
                          ),
                        ),
                      const SizedBox(height: 26),
                      if (desktop)
                        const Text(
                          'MI PARQUEADERO',
                          style: TextStyle(
                            fontSize: 9,
                            color: ParkColors.muted,
                          ),
                        ),
                      const SizedBox(height: 26),
                      for (final item in items)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: nav(item, compact: !desktop),
                        ),
                      if (desktop)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: ParkColors.background,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Universidad\nSanto Tomás',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 12),
                              Text(
                                'Parqueadero prepago',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: ParkColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      desktop ? 36 : 24,
                      rail ? 36 : 24,
                      desktop ? 36 : 24,
                      rail ? 24 : 20,
                    ),
                    child: Row(
                      children: [
                        if (rail)
                          Expanded(
                            child: Text(
                              'ParkU / $breadcrumb',
                              style: const TextStyle(
                                fontSize: 11,
                                color: ParkColors.muted,
                              ),
                            ),
                          )
                        else
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: logo(),
                            ),
                          ),
                        if (!rail) const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Text(
                            roleName,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (!rail) const Spacer(),
                        if (initials.isNotEmpty && rail) ...[
                          const SizedBox(width: 14),
                          Text(
                            initials,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                        if (refresh != null)
                          IconButton(
                            onPressed: busy ? null : refresh,
                            tooltip: 'Actualizar $breadcrumb',
                            icon: const Icon(Icons.refresh, size: 20),
                          ),
                        if (api?.currentUser != null)
                          IconButton(
                            onPressed: busy ? null : () => _logout(context),
                            tooltip: 'Cerrar sesión',
                            icon: const Icon(Icons.logout, size: 19),
                          ),
                        if (Navigator.canPop(context))
                          IconButton(
                            onPressed: busy
                                ? null
                                : () => Navigator.pop(context),
                            tooltip: 'Volver',
                            icon: const Icon(Icons.arrow_back, size: 20),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: scroll
                        ? SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: content,
                            ),
                          )
                        : child,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: rail
          ? null
          : SafeArea(
              top: false,
              child: Material(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    children: [
                      for (final item in items)
                        Expanded(
                          child: InkWell(
                            onTap: busy || api == null
                                ? null
                                : () => open(context, api!, item.$1),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 1,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ParkGlyph(
                                    item.$2,
                                    size: 21,
                                    color: selected == item.$1
                                        ? ParkColors.ink
                                        : ParkColors.muted,
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    item.$3,
                                    maxLines: 1,
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: selected == item.$1
                                          ? ParkColors.ink
                                          : ParkColors.muted,
                                      fontWeight: selected == item.$1
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
