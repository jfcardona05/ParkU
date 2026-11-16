import 'package:flutter/material.dart';
import '../models/vehicle_model.dart';
import '../services/api_service.dart';
import 'park_widgets.dart';

class ParkVehicleCard extends StatefulWidget {
  final VehicleModel vehicle;
  final ApiService api;
  final VoidCallback onQr;
  final VoidCallback? onDelete;
  const ParkVehicleCard({super.key, required this.vehicle, required this.api, required this.onQr, this.onDelete});
  @override
  State<ParkVehicleCard> createState() => _ParkVehicleCardState();
}
class _ParkVehicleCardState extends State<ParkVehicleCard> {
  late Future<Map<String, dynamic>> _status;
  @override
  void initState() {
    super.initState();
    _status = widget.api.request('GET', '/api/vehicles/' + widget.vehicle.id.toString() + '/parking');
    _status.ignore();
  }
  @override
  Widget build(BuildContext context) => ParkCard(child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(children: [
        Icon(widget.vehicle.isMoto ? Icons.two_wheeler_outlined : Icons.directions_car_outlined, size: 21),
        const SizedBox(width: 10),
        Expanded(child: Text(widget.vehicle.plate, style: Theme.of(context).textTheme.titleMedium)),
        if (widget.onDelete != null) IconButton(onPressed: widget.onDelete, tooltip: 'Desvincular vehículo', icon: const Icon(Icons.more_horiz)),
      ]),
      Text((widget.vehicle.isMoto ? 'Moto' : 'Automóvil') + (widget.vehicle.brandModel.isEmpty ? '' : ' · ' + widget.vehicle.brandModel), style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 20),
      ParkCar(motorcycle: widget.vehicle.isMoto),
      const SizedBox(height: 16),
      FutureBuilder<Map<String, dynamic>>(
        future: _status,
        builder: (context, snapshot) => ParkBadge(
          snapshot.connectionState != ConnectionState.done ? 'Consultando estado…'
          : snapshot.hasError ? 'Estado no disponible'
          : snapshot.data?['parking_state'] == 'INSIDE' ? 'Dentro del parqueadero'
          : snapshot.data?['parking_state'] == 'OUTSIDE' ? 'Fuera del parqueadero' : 'Estado no disponible',
          success: snapshot.data?['parking_state'] == 'INSIDE',
        ),
      ),
      const SizedBox(height: 16),
      Tooltip(message: 'Mostrar QR', child: FilledButton(onPressed: widget.onQr, child: const Text('Mostrar mi QR →'))),
    ],
  ));
}
