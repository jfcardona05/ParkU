import '../models/vehicle_model.dart';
import 'api_service.dart';

class VehicleQr {
  final int vehicleId;
  final String token;
  final DateTime expiresAt;
  final bool daily;
  final int amount;
  final String? scanUrl;
  const VehicleQr({
    required this.vehicleId,
    required this.token,
    required this.expiresAt,
    this.daily = false,
    this.amount = 0,
    this.scanUrl,
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

class DailyQrQuote {
  final int amount;
  final String serviceDate;
  final VehicleQr? qr;
  const DailyQrQuote({
    required this.amount,
    required this.serviceDate,
    this.qr,
  });
}

abstract class DailyVehicleQrSource implements VehicleQrSource {
  Future<DailyQrQuote> lookup(VehicleModel vehicle);
}

class ApiVehicleQrSource extends DailyVehicleQrSource {
  final ApiService api;
  DailyQrQuote? _quote;
  ApiVehicleQrSource(this.api);
  @override
  bool get isDemo => false;

  VehicleQr _parse(Map<String, dynamic> data, VehicleModel vehicle) {
    try {
      final token = data['token'] as String;
      final qr = VehicleQr(
        vehicleId: data['vehicle_id'] as int,
        token: token,
        expiresAt: DateTime.parse(data['expires_at'] as String).toUtc(),
        daily: data['daily'] == true,
        amount: data['amount'] as int? ?? 0,
        scanUrl: api.qrScanUrl(token),
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

  @override
  Future<DailyQrQuote> lookup(VehicleModel vehicle) async {
    api.qrScanUrl('configuration-check');
    final data = await api.request('GET', '/api/vehicles/${vehicle.id}/qr');
    if (data['vehicle_id'] != vehicle.id ||
        data['amount'] is! int ||
        (data['amount'] as int) <= 0 ||
        data['service_date'] is! String ||
        data['issued'] is! bool) {
      throw const ApiException('No se pudo consultar la tarifa del QR diario.');
    }
    final quote = DailyQrQuote(
      amount: data['amount'] as int,
      serviceDate: data['service_date'] as String,
      qr: data['issued'] == true ? _parse(data, vehicle) : null,
    );
    _quote = quote;
    return quote;
  }

  @override
  Future<VehicleQr> issue(VehicleModel vehicle) async {
    final quote = _quote;
    final data = await api.request(
      'POST',
      '/api/vehicles/${vehicle.id}/qr',
      quote == null
          ? null
          : {
              'expected_amount': quote.amount,
              'service_date': quote.serviceDate,
            },
    );
    final qr = _parse(data, vehicle);
    final balance = data['balance_after'];
    if (balance is int) {
      api.setCurrentUser(api.currentUser?.copyWith(balance: balance));
    }
    return qr;
  }
}
