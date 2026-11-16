import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../ui/park_shell.dart';
import '../ui/park_widgets.dart';
import '../ui/park_theme.dart';

class AddVehicleScreen extends StatefulWidget {
  final ApiService apiService;

  const AddVehicleScreen({super.key, required this.apiService});

  @override
  State<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends State<AddVehicleScreen> {
  final _plateController = TextEditingController();
  final _brandController = TextEditingController();
  String _selectedType = 'automovil';
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _plateController.dispose();
    _brandController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final plate = _plateController.text.trim().toUpperCase();

    // Criterio 2 HU-06: Si falta la placa o el tipo, no se guarda y se muestra mensaje claro
    if (plate.isEmpty) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'La placa del vehículo es obligatoria.';
      });
      return;
    }

    if (_selectedType.isEmpty) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'El tipo de vehículo es obligatorio.';
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await widget.apiService.addVehicle(
      plate: plate,
      type: _selectedType,
      brandModel: _brandController.text.trim(),
    );

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });

    if (res['success'] == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Vehículo guardado exitosamente.'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
      Navigator.pop(context, true);
    } else {
      if (!mounted) return;
      setState(() {
        _errorMessage = res['message'] ?? 'Error al registrar vehículo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => ParkShell(
    api: widget.apiService,
    selected: 1,
    breadcrumb: 'Agregar vehículo',
    busy: _isLoading,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ParkHeading(
          'Un vehículo.\nTu próximo recorrido.',
          'Registra los vehículos de tu propiedad.',
        ),
        ParkColumns(
          children: [
            ParkCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Agregar vehículo',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _plateController,
                    enabled: !_isLoading,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Placa *',
                      hintText: 'ABC123',
                    ),
                  ),
                  const SizedBox(height: 18),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de vehículo *',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'automovil',
                        child: Text('Automóvil'),
                      ),
                      DropdownMenuItem(value: 'moto', child: Text('Moto')),
                    ],
                    onChanged: _isLoading
                        ? null
                        : (value) {
                            if (value != null)
                              setState(() => _selectedType = value);
                          },
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _brandController,
                    enabled: !_isLoading,
                    decoration: const InputDecoration(
                      labelText: 'Marca y modelo',
                      hintText: 'Ej. Chevrolet Onix',
                    ),
                  ),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Color(0xFFB3261E)),
                      ),
                    ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _isLoading ? null : _handleSave,
                    child: Text(_isLoading ? 'Guardando…' : 'Guardar vehículo'),
                  ),
                ],
              ),
            ),
            ParkCard(
              color: ParkColors.yellow,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ParkIcon(Icons.directions_car_outlined),
                  const SizedBox(height: 20),
                  Text(
                    'Listo para tu\npróxima entrada.',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Tu QR es personal, temporal y de un solo uso. Genéralo antes de llegar a portería.',
                  ),
                  const SizedBox(height: 24),
                  ParkCar(motorcycle: _selectedType == 'moto'),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
