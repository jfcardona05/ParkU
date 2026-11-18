import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parku_mobile/models/user_model.dart';
import 'package:parku_mobile/models/vehicle_model.dart';
import 'package:parku_mobile/screens/transfer_screen.dart';
import 'package:parku_mobile/screens/vehicle_qr_screen.dart';
import 'package:parku_mobile/services/api_service.dart';
import 'package:parku_mobile/services/vehicle_qr_service.dart';
import 'package:parku_mobile/ui/park_theme.dart';
import 'package:qr_flutter/qr_flutter.dart';

final car = VehicleModel(
  id: 1,
  plate: 'CAR123',
  type: 'automovil',
  brandModel: '',
  createdAt: '',
);
http.Response jsonResponse(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
ApiService service(Future<http.Response> Function(http.Request) response) =>
    ApiService(client: MockClient(response))
      ..setToken('fixture')
      ..setCurrentUser(
        UserModel(
          id: 1,
          name: 'Prueba',
          email: 'sender@test.co',
          role: 'estudiante',
          balance: 10000,
        ),
      );
Future<void> openQr(WidgetTester tester, ApiService api) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: parkTheme(),
      home: VehicleQrScreen(
        vehicle: car,
        source: ApiVehicleQrSource(api),
        apiService: api,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> enterTransfer(WidgetTester tester, ApiService api) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: parkTheme(),
      home: TransferScreen(apiService: api),
    ),
  );
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField).at(0), 'receiver@test.co');
  await tester.enterText(find.byType(TextFormField).at(1), '3000');
}

void main() {
  testWidgets(
    'opening and cancelling a daily pass never charges; confirmation charges once',
    (tester) async {
      var posts = 0;
      var issued = false;
      final api = service((request) async {
        if (request.method == 'POST') {
          posts++;
          issued = true;
          expect(jsonDecode(request.body), {
            'expected_amount': 5000,
            'service_date': '2030-01-01',
          });
        }
        return jsonResponse({
          'vehicle_id': 1,
          'daily': true,
          'issued': issued,
          'amount': 5000,
          'service_date': '2030-01-01',
          if (issued) ...{
            'token': 'paid-token',
            'expires_at': DateTime.now()
                .toUtc()
                .add(const Duration(hours: 2))
                .toIso8601String(),
            'balance_after': 5000,
          },
        });
      });
      await openQr(tester, api);
      expect(posts, 0);
      expect(find.byType(QrImageView), findsNothing);
      await tester.ensureVisible(find.text('Generar QR diario'));
      await tester.tap(find.text('Generar QR diario'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(posts, 0);
      await tester.tap(find.text('Generar QR diario'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar y generar'));
      await tester.pumpAndSettle();
      expect(posts, 1);
      expect(api.currentUser!.balance, 5000);
      expect(find.byType(QrImageView), findsOneWidget);
      await tester.ensureVisible(find.text('Consultar QR de hoy'));
      await tester.tap(find.text('Consultar QR de hoy'));
      await tester.pumpAndSettle();
      expect(posts, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'changed tariff returns to a free quote rather than silently charging',
    (tester) async {
      var posts = 0;
      final api = service((request) async {
        if (request.method == 'POST') {
          posts++;
          return jsonResponse({
            'message': 'Cambió la tarifa',
            'code': 'PRICE_CHANGED',
          }, 409);
        }
        return jsonResponse({
          'vehicle_id': 1,
          'daily': true,
          'issued': false,
          'amount': 5000,
          'service_date': '2030-01-01',
        });
      });
      await openQr(tester, api);
      await tester.ensureVisible(find.text('Generar QR diario'));
      await tester.tap(find.text('Generar QR diario'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar y generar'));
      await tester.pumpAndSettle();
      expect(find.text('Cambió la tarifa'), findsOneWidget);
      await tester.ensureVisible(find.text('Consultar pase diario'));
      await tester.tap(find.text('Consultar pase diario'));
      await tester.pumpAndSettle();
      expect(posts, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'transfer validation and cancelling confirmation never sends money',
    (tester) async {
      var posts = 0;
      final api = service((r) async {
        if (r.method == 'POST') posts++;
        return jsonResponse({'balance': 10000});
      });
      await enterTransfer(tester, api);
      await tester.enterText(find.byType(TextFormField).at(1), '0');
      await tester.ensureVisible(find.text('Transferir saldo'));
      await tester.tap(find.text('Transferir saldo'));
      await tester.pumpAndSettle();
      expect(posts, 0);
      await tester.enterText(find.byType(TextFormField).at(1), '3000');
      await tester.tap(find.text('Transferir saldo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(posts, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'lost transfer response retries with the same key and preserves pending data across navigation',
    (tester) async {
      final keys = <String>[];
      var committed = false;
      final api = service((r) async {
        if (r.method == 'GET') {
          return jsonResponse({'balance': committed ? 7000 : 10000});
        }
        final body = jsonDecode(r.body) as Map;
        keys.add(body['request_id'] as String);
        if (keys.length == 1) {
          committed = true;
          throw http.ClientException('Lost response after commit');
        }
        return jsonResponse({
          'success': true,
          'transfer_id': 'receipt-1',
          'recipient_email': 'receiver@test.co',
          'amount': 3000,
          'balance_after': 7000,
        });
      });
      await enterTransfer(tester, api);
      await tester.ensureVisible(find.text('Transferir saldo'));
      await tester.tap(find.text('Transferir saldo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar envío'));
      await tester.pumpAndSettle();
      expect(keys, hasLength(1));
      expect(api.pendingTransfer, isNotNull);
      expect(
        tester.widget<TextFormField>(find.byType(TextFormField).first).enabled,
        false,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        MaterialApp(
          theme: parkTheme(),
          home: TransferScreen(apiService: api),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Reintentar transferencia'));
      await tester.tap(find.text('Reintentar transferencia'));
      await tester.pumpAndSettle();
      expect(keys, hasLength(2));
      expect(keys[1], keys[0]);
      expect(api.pendingTransfer, isNull);
      expect(api.currentUser!.balance, 7000);
      expect(find.text('Transferencia realizada'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('definitive insufficient-funds response unlocks transfer form', (
    tester,
  ) async {
    final api = service(
      (r) async => r.method == 'GET'
          ? jsonResponse({'balance': 1000})
          : jsonResponse({
              'message': 'Saldo insuficiente',
              'code': 'INSUFFICIENT_BALANCE',
            }, 409),
    );
    await enterTransfer(tester, api);
    await tester.ensureVisible(find.text('Transferir saldo'));
    await tester.tap(find.text('Transferir saldo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar envío'));
    await tester.pumpAndSettle();
    expect(find.text('Saldo insuficiente'), findsOneWidget);
    expect(api.pendingTransfer, isNull);
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField).first).enabled,
      true,
    );
    await tester.pumpWidget(const SizedBox());
  });
}
