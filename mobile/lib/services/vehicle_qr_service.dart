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

/// QR sources share the same screen for the API and explicit demonstration.
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

class ApiVehicleQrSource implements VehicleQrSource {
  final ApiService api;
  ApiVehicleQrSource(this.api);
  @override
  bool get isDemo => false;

  @override
  Future<VehicleQr> issue(VehicleModel vehicle) async {
    final data = await api.request('POST', '/api/vehicles/${vehicle.id}/qr');
    try {
      final qr = VehicleQr(
        vehicleId: data['vehicle_id'] as int,
        token: data['token'] as String,
        expiresAt: DateTime.parse(data['expires_at'] as String).toUtc(),
      );
      if (qr.vehicleId != vehicle.id || qr.token.isEmpty) {
        throw const FormatException();
      }
      return qr;
    } on Object {
      throw const ApiException(
        'El servicio devolvió un QR inválido. Intenta nuevamente.',
      );
    }
  }
}
