import '../models/vehicle_model.dart';
import 'api_service.dart';

class ParkedVehicle {
  final VehicleModel vehicle;
  final bool inside;
  final DateTime? enteredAt;
  const ParkedVehicle(this.vehicle, this.inside, this.enteredAt);
}

class ParkingHistoryPage {
  final List<Map<String, dynamic>> operations;
  final int? nextBeforeId;
  const ParkingHistoryPage(this.operations, this.nextBeforeId);
}

class ParkingService {
  final ApiService api;
  ParkingService(this.api);

  Future<List<ParkedVehicle>> getVehicles() async {
    final vehicles = await api.getVehicles();
    return Future.wait(
      vehicles.map((vehicle) async {
        final data = await api.request(
          'GET',
          '/api/vehicles/${vehicle.id}/parking',
        );
        if (data['vehicle_id'] != vehicle.id ||
            !['INSIDE', 'OUTSIDE'].contains(data['parking_state'])) {
          throw const ApiException(
            'No se pudo interpretar el estado del vehículo.',
          );
        }
        return ParkedVehicle(
          vehicle,
          data['parking_state'] == 'INSIDE',
          data['entered_at'] == null
              ? null
              : DateTime.parse(data['entered_at'] as String),
        );
      }),
    );
  }

  Future<Map<String, dynamic>> getOccupancy() =>
      api.request('GET', '/api/parking/occupancy');

  Future<List<Map<String, dynamic>>> getRates() async {
    final data = await api.request('GET', '/api/parking/rates');
    return (data['rates'] as List).cast<Map<String, dynamic>>();
  }

  Future<ParkingHistoryPage> getHistory({int? beforeId}) async {
    final cursor = beforeId == null ? '' : '&before_id=$beforeId';
    final data = await api.request(
      'GET',
      '/api/parking/history?limit=20$cursor',
    );
    return ParkingHistoryPage(
      (data['operations'] as List).cast<Map<String, dynamic>>(),
      data['next_before_id'] as int?,
    );
  }
}
