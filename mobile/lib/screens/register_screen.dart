import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../ui/park_shell.dart';
import '../ui/park_widgets.dart';
import '../ui/park_theme.dart';

class RegisterScreen extends StatefulWidget {
  final ApiService apiService;
  const RegisterScreen({super.key, required this.apiService});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _document = TextEditingController();
  String _documentType = 'CC';
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _document.dispose();
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_busy) return;
    if (_name.text.trim().isEmpty ||
        _email.text.trim().isEmpty ||
        _password.text.length < 6 ||
        !RegExp(r'^[0-9]{5,15}$').hasMatch(_document.text.trim())) {
      setState(
        () => _error =
            'Completa tus datos, documento de 5 a 15 dígitos y usa una contraseña de al menos 6 caracteres.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.apiService.request('POST', '/api/auth/register', {
        'name': _name.text.trim(),
        'email': _email.text.trim(),
        'password': _password.text,
        'document_type': _documentType,
        'document_number': _document.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cuenta creada. Ya puedes iniciar sesión.'),
        ),
      );
      Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ApiException
              ? error.message
              : 'No se pudo crear la cuenta.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ParkShell(
    api: widget.apiService,
    selected: -1,
    breadcrumb: 'Crear cuenta',
    busy: _busy,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ParkHeading(
          'Tu próximo recorrido\nempieza aquí.',
          'Crea tu cuenta de ParkU.',
        ),
        ParkColumns(
          children: [
            ParkCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Regístrate',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _name,
                    enabled: !_busy,
                    autofillHints: const [AutofillHints.name],
                    decoration: const InputDecoration(
                      labelText: 'Nombre completo',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _email,
                    enabled: !_busy,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _documentType,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de documento',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'CC',
                        child: Text(
                          'Cédula de ciudadanía',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'TI',
                        child: Text(
                          'Tarjeta de identidad',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _documentType = v!),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _document,
                    enabled: !_busy,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Número de documento',
                      hintText: 'Sin puntos ni espacios',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _password,
                    enabled: !_busy,
                    obscureText: true,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: const InputDecoration(labelText: 'Contraseña'),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Color(0xFFB3261E)),
                      ),
                    ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _busy ? null : _register,
                    child: Text(
                      _busy ? 'Creando cuenta…' : 'Crear mi cuenta →',
                    ),
                  ),
                ],
              ),
            ),
            const ParkCard(
              color: ParkColors.yellowLight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ParkIcon(Icons.directions_car_outlined),
                  SizedBox(height: 22),
                  Text(
                    'Tu vehículo.\nTu QR. Tu lugar.',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Registra tu vehículo y consulta tu saldo con una sola cuenta.',
                  ),
                  SizedBox(height: 24),
                  ParkCar(motorcycle: true),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
