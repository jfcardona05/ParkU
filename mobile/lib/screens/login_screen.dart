import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../ui/park_shell.dart';
import '../ui/park_widgets.dart';
import '../ui/park_theme.dart';
import 'register_screen.dart';
import 'dashboard_screen.dart';
import 'taquilla_screen.dart';
import 'gate_screen.dart';
import '../services/gate_service.dart';

class LoginScreen extends StatefulWidget {
  final ApiService apiService;

  const LoginScreen({super.key, required this.apiService});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Por favor ingresa tu correo y contraseña.';
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await widget.apiService.login(email, password);

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });

    if (result['success'] == true) {
      if (!mounted) return;
      final user = widget.apiService.currentUser;

      // REGLA: Si el usuario es el Operador de Taquilla, se abre el módulo de Taquilla
      // Si es un conductor/estudiante, se abre el Dashboard sin opción de recarga propia
      final destination = (user?.role == 'guard' || user?.role == 'admin')
          ? GateScreen(
              apiService: widget.apiService,
              gateway: ApiGateGateway(widget.apiService),
            )
          : (user?.role == 'operador')
          ? TaquillaScreen(apiService: widget.apiService)
          : DashboardScreen(apiService: widget.apiService);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => destination),
      );
    } else {
      // Criterio 2 HU-01: Rechazo de acceso y no revelar saldo
      if (!mounted) return;
      setState(() {
        _errorMessage = result['message'] ?? 'Credenciales incorrectas.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 760;
    final intro = ParkCard(
      color: mobile ? ParkColors.background : ParkColors.yellow,
      padding: EdgeInsets.all(mobile ? 0 : 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!mobile)
            const Text(
              'MENOS VUELTAS. MÁS TIEMPO.',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
            ),
          const SizedBox(height: 22),
          Text(
            'Tu parqueadero,\nmás fácil.',
            style: mobile
                ? Theme.of(
                    context,
                  ).textTheme.headlineMedium?.copyWith(fontSize: 28)
                : Theme.of(
                    context,
                  ).textTheme.headlineLarge?.copyWith(fontSize: 55),
          ),
          const SizedBox(height: 22),
          Text(
            mobile
                ? 'Bienvenido a ParkU'
                : 'Gestiona tu vehículo, consulta tu saldo\ny entra con un QR seguro.',
            style: mobile
                ? Theme.of(context).textTheme.bodySmall
                : Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 22),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: mobile ? 300 : 490),
            child: const ParkCar(),
          ),
        ],
      ),
    );
    final form = ParkCard(
      padding: EdgeInsets.all(mobile ? 0 : 32),
      color: mobile ? ParkColors.background : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Inicia sesión',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontSize: mobile ? 28 : 36),
          ),
          const SizedBox(height: 14),
          Text(
            'Ingresa con tu cuenta de ParkU.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 26),
          if (_errorMessage != null) ...[
            Text(
              _errorMessage!,
              style: const TextStyle(color: Color(0xFFB3261E)),
            ),
            const SizedBox(height: 16),
          ],
          const Text(
            'Correo electrónico',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _emailController,
            enabled: !_isLoading,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.username],
            decoration: const InputDecoration(
              hintText: 'tu.correo@usantotomas.edu.co',
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Contraseña',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _passwordController,
            enabled: !_isLoading,
            obscureText: true,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => _isLoading ? null : _handleLogin(),
            decoration: const InputDecoration(hintText: '••••••••'),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _isLoading ? null : _handleLogin,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Ingresar a ParkU →'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _isLoading
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          RegisterScreen(apiService: widget.apiService),
                    ),
                  ),
            child: const Text('¿Aún no tienes cuenta? Regístrate'),
          ),
          Text(
            'Acceso de portería y taquilla según tu rol.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
    return ParkShell(
      api: widget.apiService,
      selected: -1,
      breadcrumb: 'Iniciar sesión',
      busy: _isLoading,
      child: Column(
        children: [
          ParkColumns(
            flex: const [600, 492],
            gap: 40,
            breakpoint: 760,
            children: [intro, form],
          ),
          if (!mobile) ...[
            const SizedBox(height: 20),
            const ParkFeatures(
              items: [
                (
                  Icons.directions_car_outlined,
                  'Tu vehículo',
                  'Registra los vehículos que utilizas.',
                ),
                (
                  Icons.qr_code_2_outlined,
                  'Tu QR seguro',
                  'Genera el código antes de llegar.',
                ),
                (
                  Icons.account_balance_wallet_outlined,
                  'Tu saldo',
                  'Consulta tus movimientos en un lugar.',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
