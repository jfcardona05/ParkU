import 'package:flutter/material.dart';
import '../services/api_service.dart';

class RechargeScreen extends StatelessWidget {
  final ApiService apiService;
  const RechargeScreen({super.key, required this.apiService});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Recarga presencial')),
    body: const Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.storefront, size: 48, color: Color(0xFFF59E0B)),
          SizedBox(height: 24),
          Text(
            'Recarga tu saldo en taquilla',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          Text(
            'Acércate a uno de los puntos físicos, indica el correo de tu cuenta y entrega el efectivo al operador.',
          ),
          SizedBox(height: 16),
          Text(
            'Punto 1 · Portería Principal USTA\nPunto 2 · Cafetería Central USTA',
          ),
          SizedBox(height: 16),
          Text(
            'El operador registrará el abono. Después actualiza tu saldo para consultar la recarga y su referencia en el historial.',
          ),
        ],
      ),
    ),
  );
}
