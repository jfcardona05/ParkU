import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../ui/park_shell.dart';
import '../ui/park_widgets.dart';
import '../ui/park_theme.dart';

class RechargeScreen extends StatelessWidget {
  final ApiService apiService;
  const RechargeScreen({super.key, required this.apiService});
  @override
  Widget build(BuildContext context) => ParkShell(
    api: apiService,
    selected: 2,
    breadcrumb: 'Recarga presencial',
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ParkHeading(
          'Recarga en taquilla',
          'Tu saldo, listo para tu próximo recorrido.',
        ),
        ParkCard(
          color: ParkColors.yellow,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ParkIcon(Icons.storefront_outlined),
              SizedBox(height: 24),
              Text(
                'Recarga tu saldo en taquilla',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 24),
              Text(
                'Acércate a uno de los puntos físicos, indica el correo de tu cuenta y entrega el efectivo al operador.',
              ),
              SizedBox(height: 24),
              Text(
                'Punto 1 · Portería Principal USTA\nPunto 2 · Cafetería Central USTA',
              ),
              SizedBox(height: 24),
              Text(
                'El operador registrará el abono. Después actualiza tu saldo para consultar la recarga y su referencia en el historial.',
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
