import 'api_service.dart';

enum GateAction { entry, exit }

class GatePreview {
  final String token;
  final String plate;
  final DateTime expiresAt;
  const GatePreview({
    required this.token,
    required this.plate,
    required this.expiresAt,
  });
}

abstract class GateGateway {
  bool get isDemo;
  Future<GatePreview> inspect(String token);
  Future<String> confirm(
    GatePreview preview,
    GateAction action,
    String requestId,
  );
}

class UnavailableGateGateway implements GateGateway {
  const UnavailableGateGateway();
  @override
  bool get isDemo => false;
  @override
  Future<GatePreview> inspect(String token) async => throw const ApiException(
    'Portería aún no está conectada. Intenta más tarde.',
  );
  @override
  Future<String> confirm(
    GatePreview preview,
    GateAction action,
    String requestId,
  ) async => throw const ApiException('Portería aún no está conectada.');
}

/// In-memory simulation only; never grants real access or charges a wallet.
class DemoGateGateway implements GateGateway {
  final Set<String> _inside = {};
  final Set<String> _consumed = {};
  final Map<String, String> _receipts = {};
  @override
  bool get isDemo => true;
  @override
  Future<GatePreview> inspect(String token) async {
    final parts = token.trim().split(':');
    if (parts.length != 3 ||
        parts[0] != 'PARKU-DEMO' ||
        int.tryParse(parts[1]) == null ||
        int.tryParse(parts[2]) == null) {
      throw const ApiException('QR inválido para demostración.');
    }
    final expiry = DateTime.fromMillisecondsSinceEpoch(
      int.parse(parts[2]),
      isUtc: true,
    );
    if (!DateTime.now().toUtc().isBefore(expiry)) {
      throw const ApiException('QR vencido. Solicita uno nuevo.');
    }
    if (_consumed.contains(token)) {
      throw const ApiException('Este QR ya fue utilizado.');
    }
    return GatePreview(
      token: token,
      plate: 'Vehículo demo ${parts[1]}',
      expiresAt: expiry,
    );
  }

  @override
  Future<String> confirm(
    GatePreview preview,
    GateAction action,
    String requestId,
  ) async {
    if (_receipts.containsKey(requestId)) return _receipts[requestId]!;
    await inspect(preview.token);
    final vehicle = preview.token.split(':')[1];
    if (action == GateAction.entry && _inside.contains(vehicle)) {
      throw const ApiException('El vehículo ya tiene un ingreso activo.');
    }
    if (action == GateAction.exit && !_inside.contains(vehicle)) {
      throw const ApiException('El vehículo no tiene un ingreso activo.');
    }
    if (action == GateAction.entry) {
      _inside.add(vehicle);
    } else {
      _inside.remove(vehicle);
    }
    _consumed.add(preview.token);
    final receipt =
        'DEMOSTRACIÓN: ${action == GateAction.entry ? 'Ingreso' : 'Salida'} registrado para ${preview.plate}. Sin cobro real.';
    _receipts[requestId] = receipt;
    return receipt;
  }
}
