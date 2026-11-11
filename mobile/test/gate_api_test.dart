import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parku_mobile/main.dart';
import 'package:parku_mobile/models/user_model.dart';
import 'package:parku_mobile/screens/gate_screen.dart';
import 'package:parku_mobile/services/api_service.dart';
import 'package:parku_mobile/services/gate_service.dart';

class LostReplyGateway implements GateGateway {
  final ids = <String>[];
  late DateTime expiry;
  @override
  bool get isDemo => false;
  @override
  Future<GatePreview> inspect(String token) async {
    expiry = DateTime.now().add(const Duration(seconds: 1));
    return GatePreview(token: token, plate: 'ABC123', expiresAt: expiry);
  }

  @override
  Future<String> confirm(
    GatePreview preview,
    GateAction action,
    String requestId,
  ) async {
    ids.add(requestId);
    if (ids.length == 1) throw const ApiException('Se perdió la respuesta');
    return 'Ingreso registrado';
  }
}

void main() {
  testWidgets(
    'guard login opens live gateway and confirms server-selected exit',
    (tester) async {
      final operations = <Map<String, dynamic>>[];
      final api = ApiService(
        client: MockClient((request) async {
          final path = request.url.path;
          if (path == '/api/auth/login') {
            return jsonResponse(
              jsonEncode({
                'token': 'guard-session',
                'user': {
                  'id': 3,
                  'name': 'Portería',
                  'role': 'guard',
                  'balance': 0,
                },
              }),
              200,
            );
          }
          expect(request.headers['Authorization'], 'Bearer guard-session');
          if (path == '/api/gate/inspect') {
            return jsonResponse(
              jsonEncode({
                'success': true,
                'vehicle_id': 7,
                'plate': 'ABC123',
                'expires_at': DateTime.now()
                    .toUtc()
                    .add(const Duration(minutes: 2))
                    .toIso8601String(),
                'parking_state': 'INSIDE',
                'allowed_action': 'exit',
              }),
              200,
            );
          }
          expect(path, '/api/gate/operations');
          operations.add(jsonDecode(request.body) as Map<String, dynamic>);
          return jsonResponse(
            jsonEncode({
              'success': true,
              'operation_id': 1,
              'vehicle_id': 7,
              'action': 'exit',
              'parking_state': 'OUTSIDE',
              'message': 'Salida registrada',
              'charge': {
                'amount': 5000,
                'balance_after': 3000,
                'parking_rate_label': '5000 COP por bloque',
              },
            }),
            201,
          );
        }),
      );
      await tester.pumpWidget(ParkUApp(apiService: api));
      await tester.enterText(
        find.byType(TextField).first,
        'guard@example.test',
      );
      await tester.enterText(find.byType(TextField).last, 'password');
      await tester.ensureVisible(find.text('Ingresar a mi Cuenta'));
      await tester.tap(find.text('Ingresar a mi Cuenta'));
      await tester.pumpAndSettle();
      expect(find.text('Portería'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'opaque-token');
      await tester.tap(find.text('Validar código'));
      await tester.pumpAndSettle();
      expect(find.text('Operación: Salida'), findsOneWidget);
      expect(operations, isEmpty);

      await tester.ensureVisible(find.text('Confirmar operación'));
      await tester.tap(find.text('Confirmar operación'));
      await tester.pumpAndSettle();
      expect(operations.single['action'], 'exit');
      expect(operations.single['token'], 'opaque-token');
      expect(
        (operations.single['request_id'] as String).length,
        greaterThan(20),
      );
      expect(find.textContaining('Cobro: \$5000 COP'), findsOneWidget);
      expect(
        find.textContaining('Saldo posterior: \$3000 COP'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'lost confirmation can recover the same receipt after QR expiry',
    (tester) async {
      final gateway = LostReplyGateway();
      final api = ApiService()
        ..setCurrentUser(
          UserModel(id: 1, name: '', email: '', role: 'guard', balance: 0),
        );
      await tester.pumpWidget(
        MaterialApp(
          home: GateScreen(apiService: api, gateway: gateway),
        ),
      );
      await tester.enterText(find.byType(TextField), 'opaque');
      await tester.tap(find.text('Validar código'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar operación'));
      await tester.pumpAndSettle();
      expect(find.text('Se perdió la respuesta'), findsOneWidget);

      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1100)),
      );
      await tester.tap(find.text('Confirmar operación'));
      await tester.pumpAndSettle();
      expect(gateway.ids, hasLength(2));
      expect(gateway.ids.first, gateway.ids.last);
      expect(find.text('Ingreso registrado'), findsOneWidget);
    },
  );

  test('inspection errors preserve server codes', () async {
    final api = ApiService(
      client: MockClient(
        (_) async => jsonResponse(
          '{"success":false,"code":"QR_EXPIRED","message":"QR vencido"}',
          410,
        ),
      ),
    );
    await expectLater(
      ApiGateGateway(api).inspect('expired'),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'QR_EXPIRED')),
    );
  });
}

http.Response jsonResponse(String body, int status) => http.Response(
  body,
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
