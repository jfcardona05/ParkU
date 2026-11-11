import 'dart:convert';
import 'dart:math';

import 'api_service.dart';

enum GateAction { entry, exit }

String newGateRequestId() {
  final random = Random.secure();
  return base64UrlEncode(List.generate(24, (_) => random.nextInt(256)));
}

class GatePreview {
  final String token;
  final String plate;
  final DateTime expiresAt;
  final int? vehicleId;
  final GateAction? allowedAction;
  const GatePreview({
    required this.token,
    required this.plate,
    required this.expiresAt,
    this.vehicleId,
    this.allowedAction,
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

class ApiGateGateway implements GateGateway {
  final ApiService api;
  ApiGateGateway(this.api);

  @override
  bool get isDemo => false;

  @override
  Future<GatePreview> inspect(String token) async {
    final data = await api.request('POST', '/api/gate/inspect', {
      'token': token,
    });
    try {
      final action = switch (data['allowed_action']) {
        'entry' => GateAction.entry,
        'exit' => GateAction.exit,
        _ => throw const FormatException(),
      };
      if (data['success'] != true ||
          data['parking_state'] !=
              (action == GateAction.entry ? 'OUTSIDE' : 'INSIDE')) {
        throw const FormatException();
      }
      return GatePreview(
        token: token,
        plate: data['plate'] as String,
        vehicleId: data['vehicle_id'] as int,
        expiresAt: DateTime.parse(data['expires_at'] as String).toUtc(),
        allowedAction: action,
      );
    } on Object {
      throw const ApiException(
        'No se pudo interpretar la validación de portería.',
      );
    }
  }

  @override
  Future<String> confirm(
    GatePreview preview,
    GateAction action,
    String requestId,
  ) async {
    final data = await api.request('POST', '/api/gate/operations', {
      'token': preview.token,
      'action': action.name,
      'request_id': requestId,
    });
    try {
      if (data['success'] != true ||
          data['operation_id'] is! int ||
          data['action'] != action.name ||
          data['vehicle_id'] != preview.vehicleId ||
          data['parking_state'] !=
              (action == GateAction.entry ? 'INSIDE' : 'OUTSIDE')) {
        throw const FormatException();
      }
      final message = data['message'] as String;
      if (action == GateAction.entry) return message;
      final charge = data['charge'] as Map<String, dynamic>;
      final amount = charge['amount'] as int;
      final balance = charge['balance_after'] as int;
      final rate = charge['parking_rate_label'] as String;
      return [
        message,
        'Cobro: \$$amount COP',
        'Saldo posterior: \$$balance COP',
        'Tarifa aplicada: $rate',
      ].join('\n');
    } on Object {
      // Keeping requestId lets a retry recover the server's persisted receipt.
      throw const ApiException(
        'Respuesta incompleta. Reintenta la misma confirmación.',
      );
    }
  }
}
