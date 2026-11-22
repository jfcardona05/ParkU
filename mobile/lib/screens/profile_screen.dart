import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../models/user_model.dart';
import '../ui/park_shell.dart';
import '../ui/park_widgets.dart';
import '../ui/park_theme.dart';

class ProfileScreen extends StatefulWidget {
  final ApiService apiService;
  const ProfileScreen({super.key, required this.apiService});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _email = TextEditingController(),
      _document = TextEditingController(),
      _current = TextEditingController(),
      _password = TextEditingController(),
      _confirm = TextEditingController();
  String _type = 'CC';
  bool _busy = false;
  String? _error;
  bool _saved = false;
  @override
  void initState() {
    super.initState();
    final user = widget.apiService.currentUser;
    _name.text = user?.name ?? '';
    _email.text = user?.email ?? '';
    _document.text = user?.documentNumber ?? '';
    _type = user?.documentType ?? 'CC';
  }

  @override
  void dispose() {
    for (final c in [_name, _email, _document, _current, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _saved = false;
    });
    try {
      final data = await widget.apiService
          .request('POST', '/api/auth/profile', {
            'name': _name.text.trim(),
            'email': _email.text.trim(),
            'document_type': _type,
            'document_number': _document.text.trim(),
            'current_password': _current.text,
            if (_password.text.isNotEmpty) 'new_password': _password.text,
          });
      widget.apiService.setCurrentUser(
        UserModel.fromJson(data['user'] as Map<String, dynamic>),
      );
      _current.clear();
      _password.clear();
      _confirm.clear();
      if (mounted) setState(() => _saved = true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ParkShell(
    api: widget.apiService,
    selected: 7,
    breadcrumb: 'Usuario',
    busy: _busy,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ParkHeading(
          'Tu cuenta, a tu manera.',
          'Actualiza tus datos personales y protege tu acceso.',
        ),
        ParkColumns(
          children: [
            ParkCard(
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const ParkIcon(Icons.person_outline),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _name,
                      enabled: !_busy,
                      maxLength: 120,
                      decoration: const InputDecoration(
                        labelText: 'Nombre completo',
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Escribe tu nombre.'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _email,
                      enabled: !_busy,
                      keyboardType: TextInputType.emailAddress,
                      maxLength: 200,
                      decoration: const InputDecoration(
                        labelText: 'Correo electrónico',
                      ),
                      validator: (v) =>
                          RegExp(
                            r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                          ).hasMatch(v?.trim() ?? '')
                          ? null
                          : 'Escribe un correo válido.',
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _type,
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
                          : (v) => setState(() => _type = v!),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _document,
                      enabled: !_busy,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Número de documento',
                      ),
                      validator: (v) =>
                          RegExp(r'^[0-9]{5,15}$').hasMatch(v?.trim() ?? '')
                          ? null
                          : 'Escribe de 5 a 15 dígitos, sin puntos.',
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _current,
                      enabled: !_busy,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Contraseña actual',
                      ),
                      validator: (v) => v == null || v.isEmpty
                          ? 'Confirma tu contraseña actual.'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _password,
                      enabled: !_busy,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Nueva contraseña (opcional)',
                      ),
                      validator: (v) =>
                          v != null &&
                              v.isNotEmpty &&
                              (v.length < 6 || v.length > 72)
                          ? 'Usa entre 6 y 72 caracteres.'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirm,
                      enabled: !_busy,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Repite la nueva contraseña',
                      ),
                      validator: (v) => v != _password.text
                          ? 'Las contraseñas no coinciden.'
                          : null,
                    ),
                    const SizedBox(height: 24),
                    if (_error != null) ParkNotice(_error!),
                    if (_saved)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: ParkBadge('Datos actualizados', success: true),
                      ),
                    FilledButton(
                      onPressed: _busy ? null : _save,
                      child: Text(_busy ? 'Guardando…' : 'Guardar cambios'),
                    ),
                  ],
                ),
              ),
            ),
            const ParkCard(
              color: ParkColors.yellow,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ParkIcon(Icons.shield_outlined),
                  SizedBox(height: 24),
                  Text(
                    'Tus datos.\nTu próximo recorrido.',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 24),
                  Text(
                    'Tu documento permite que otros usuarios te envíen saldo. Confirma que esté correcto.',
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Si cambias el correo o la contraseña, se cerrarán tus otras sesiones. Esta sesión continuará activa.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
