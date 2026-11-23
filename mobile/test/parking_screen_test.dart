import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parku_mobile/screens/parking_screen.dart';
import 'package:parku_mobile/models/user_model.dart';
import 'package:parku_mobile/services/api_service.dart';
import 'package:parku_mobile/widgets/cashier_parking_overview.dart';

import 'support/cash_fixtures.dart';

void main() {
  testWidgets(
    'cashier sees reference capacity and rates without personal requests',
    (tester) async {
      final paths = <String>[];
      final api =
          ApiService(
              client: MockClient((request) async {
                paths.add(request.url.path);
                if (request.url.path == '/api/cash/current') {
                  return http.Response(
                    jsonEncode(cashCurrent()),
                    200,
                    headers: {
                      'content-type': 'application/json; charset=utf-8',
                    },
                  );
                }
                if (request.url.path != '/api/parking/rates') {
                  throw StateError(
                    'Unexpected personal request: ${request.url}',
                  );
                }
                return http.Response(jsonEncode({'rates': []}), 200);
              }),
            )
            ..setToken('cashier')
            ..setCurrentUser(
              UserModel(
                id: 3,
                name: 'Taquilla',
                email: 'taquilla@test.co',
                role: 'operador',
                balance: 0,
              ),
            );
      await tester.pumpWidget(
        MaterialApp(home: ParkingScreen(apiService: api)),
      );
      await tester.pumpAndSettle();
      expect(find.text('0/1000'), findsOneWidget);
      expect(find.text('Próximamente'), findsNothing);
      expect(find.text('Tus últimos accesos'), findsNothing);
      expect(find.text('Mis vehículos'), findsNothing);
      expect(find.text('Tu vehículo'), findsNothing);
      expect(find.text('Tarifas vigentes'), findsOneWidget);
      expect(find.text('Resumen de tu caja'), findsOneWidget);
      expect(find.text('Caja abierta'), findsOneWidget);
      expect(find.text('20.000 COP'), findsOneWidget);
      expect(find.text('10.000 COP'), findsOneWidget);
      expect(find.text('30.000 COP'), findsOneWidget);
      expect(find.text('Ir al panel de caja'), findsOneWidget);
      expect(find.text('Consultar reportes'), findsOneWidget);
      expect(
        paths,
        unorderedEquals(['/api/parking/rates', '/api/cash/current']),
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'cash summary is responsive and distinguishes no session and stale turn',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      for (final width in [390.0, 1440.0]) {
        tester.view.physicalSize = Size(width, 900);
        for (final mode in ['closed', 'open', 'stale']) {
          final data = cashCurrent(active: mode != 'closed');
          if (mode == 'stale') {
            (data['session'] as Map<String, dynamic>)['can_recharge'] = false;
          }
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: CashierParkingSummary(data: data),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            find.text(
              mode == 'closed'
                  ? 'Sin caja abierta'
                  : mode == 'open'
                  ? 'Caja abierta'
                  : 'Cierre pendiente',
            ),
            findsOneWidget,
          );
          expect(
            find.text('20.000 COP'),
            mode == 'closed' ? findsNothing : findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        }
      }
    },
  );

  testWidgets(
    'cash error can retry without hiding rates or inventing amounts',
    (tester) async {
      var fail = true;
      final api =
          ApiService(
              client: MockClient((request) async {
                if (request.url.path == '/api/parking/rates') {
                  return http.Response(jsonEncode({'rates': []}), 200);
                }
                if (request.url.path == '/api/cash/current') {
                  if (fail) {
                    return http.Response(
                      '{"message":"Caja sin conexión"}',
                      503,
                      headers: {
                        'content-type': 'application/json; charset=utf-8',
                      },
                    );
                  }
                  return http.Response(
                    jsonEncode(cashCurrent(active: false)),
                    200,
                    headers: {
                      'content-type': 'application/json; charset=utf-8',
                    },
                  );
                }
                throw StateError(request.url.path);
              }),
            )
            ..setToken('cashier')
            ..setCurrentUser(
              UserModel(
                id: 3,
                name: 'Caja',
                email: 'caja@test.co',
                role: 'operador',
                balance: 0,
              ),
            );
      await tester.pumpWidget(
        MaterialApp(home: ParkingScreen(apiService: api)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tarifas vigentes'), findsOneWidget);
      expect(find.text('Caja sin conexión'), findsOneWidget);
      expect(find.text('0 COP'), findsNothing);
      fail = false;
      await tester.ensureVisible(find.text('Reintentar'));
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('Sin caja abierta'), findsOneWidget);
      expect(find.text('Caja sin conexión'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'occupancy is forthcoming and history pagination retries safely',
    (tester) async {
      final cursors = <String?>[];
      var failedOnce = false;
      final api = ApiService(
        client: MockClient((request) async {
          final Object body;
          switch (request.url.path) {
            case '/api/vehicles':
              body = {'vehicles': []};
            case '/api/parking/rates':
              body = {
                'rates': [
                  {
                    'vehicle_type': 'moto',
                    'amount': 4000,
                    'block_seconds': 3600,
                    'minimum_blocks': 1,
                  },
                ],
              };
            case '/api/parking/history':
              final cursor = request.url.queryParameters['before_id'];
              cursors.add(cursor);
              if (cursor != null && !failedOnce) {
                failedOnce = true;
                return http.Response('{"message":"Sin red"}', 503);
              }
              body = {
                'operations': [
                  {
                    'operation_id': cursor == null ? 2 : 1,
                    'action': cursor == null ? 'exit' : 'entry',
                    'plate': 'ABC123',
                    'occurred_at': '2026-11-10T12:00:00Z',
                    'charge': null,
                  },
                ],
                'next_before_id': cursor == null ? 2 : null,
              };
            default:
              throw StateError(request.url.path);
          }
          return http.Response(jsonEncode(body), 200);
        }),
      )..setToken('student');
      await tester.pumpWidget(
        MaterialApp(home: ParkingScreen(apiService: api)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Próximamente'), findsOneWidget);
      expect(find.textContaining('4000 COP / pase diario'), findsOneWidget);
      expect(find.text('Moto'), findsOneWidget);
      await tester.ensureVisible(find.text('Cargar más accesos'));
      await tester.tap(find.text('Cargar más accesos'));
      await tester.pumpAndSettle();
      expect(find.text('Sin red'), findsOneWidget);
      await tester.ensureVisible(find.text('Cargar más accesos'));
      await tester.tap(find.text('Cargar más accesos'));
      await tester.pumpAndSettle();
      expect(find.text('Ingreso · ABC123'), findsOneWidget);
      expect(find.text('Salida · ABC123'), findsOneWidget);
      expect(cursors, [null, '2', '2']);
      expect(find.text('Cargar más accesos'), findsNothing);
    },
  );
}
