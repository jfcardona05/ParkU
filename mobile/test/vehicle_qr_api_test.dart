import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parku_mobile/models/vehicle_model.dart';
import 'package:parku_mobile/screens/vehicles_screen.dart';
import 'package:parku_mobile/services/api_service.dart';
import 'package:parku_mobile/services/vehicle_qr_service.dart';
import 'package:qr_flutter/qr_flutter.dart';

final vehicle = VehicleModel(
  id: 7,
  plate: 'ABC123',
  type: 'automovil',
  brandModel: '',
  createdAt: '',
);

void main() {
  testWidgets('Mis Vehículos opens a QR issued with the current API session', (
    tester,
  ) async {
    final requests = <http.Request>[];
    final api = ApiService(
      client: MockClient((request) async {
        requests.add(request);
        expect(request.headers['Authorization'], 'Bearer session');
        if (request.url.path == '/api/vehicles') {
          return jsonResponse(
            jsonEncode({
              'vehicles': [vehicle.toJson()],
            }),
            200,
          );
        }
        expect(request.method, 'POST');
        expect(request.url.path, '/api/vehicles/7/qr');
        return jsonResponse(
          jsonEncode({
            'vehicle_id': 7,
            'token': 'server-issued-token',
            'expires_at': DateTime.now()
                .toUtc()
                .add(const Duration(minutes: 2))
                .toIso8601String(),
          }),
          201,
        );
      }),
    )..setToken('session');
    await tester.pumpWidget(MaterialApp(home: VehiclesScreen(apiService: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Mostrar QR'));
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('QR · ABC123'), findsOneWidget);
    expect(find.textContaining('DEMOSTRACIÓN'), findsNothing);
    expect(requests, hasLength(2));
    await tester.pumpWidget(const SizedBox());
  });

  test(
    'QR API preserves server error codes and clears an expired session',
    () async {
      final api = ApiService(
        client: MockClient(
          (_) async => jsonResponse(
            '{"message":"Sesión vencida","code":"UNAUTHORIZED"}',
            401,
          ),
        ),
      )..setToken('expired');
      await expectLater(
        ApiVehicleQrSource(api).issue(vehicle),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'UNAUTHORIZED'),
        ),
      );
      expect(api.token, isNull);
    },
  );

  test('QR adapter rejects a response for a different vehicle', () async {
    final api = ApiService(
      client: MockClient(
        (_) async => jsonResponse(
          jsonEncode({
            'vehicle_id': 8,
            'token': 'another-vehicle',
            'expires_at': DateTime.now().toUtc().toIso8601String(),
          }),
          201,
        ),
      ),
    );
    await expectLater(
      ApiVehicleQrSource(api).issue(vehicle),
      throwsA(isA<ApiException>()),
    );
  });
}

http.Response jsonResponse(String body, int status) => http.Response(
  body,
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
