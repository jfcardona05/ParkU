import '../models/vehicle_model.dart';
import 'api_service.dart';

class VehicleQr {
  final int vehicleId;
  final String token;
  final DateTime expiresAt;
  const VehicleQr({
    required this.vehicleId,
    required this.token,
    required this.expiresAt,
  });
  bool isExpired(DateTime now) => !now.isBefore(expiresAt);
}

/// S2-00 must agree the server contract before implementing a live adapter.
abstract class VehicleQrSource {
  bool get isDemo;
  Future<VehicleQr> issue(VehicleModel vehicle);
}

class UnavailableVehicleQrSource implements VehicleQrSource {
  const UnavailableVehicleQrSource();
  @override
  bool get isDemo => false;
  @override
  Future<VehicleQr> issue(VehicleModel vehicle) async {
    throw const ApiException(
      'El servicio QR aún no está disponible. Intenta más tarde.',
    );
  }
}

class DemoVehicleQrSource implements VehicleQrSource {
  @override
  bool get isDemo => true;
  @override
  Future<VehicleQr> issue(VehicleModel vehicle) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final expiry = DateTime.now().toUtc().add(const Duration(minutes: 2));
    return VehicleQr(
      vehicleId: vehicle.id,
      token: 'PARKU-DEMO:${vehicle.id}:${expiry.millisecondsSinceEpoch}',
      expiresAt: expiry,
    );
  }
}
