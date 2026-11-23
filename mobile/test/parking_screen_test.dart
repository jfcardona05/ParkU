import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parku_mobile/screens/parking_screen.dart';
import 'package:parku_mobile/models/user_model.dart';
import 'package:parku_mobile/services/api_service.dart';

void main() {
  testWidgets(
    'cashier sees reference capacity and rates without personal requests',
    (tester) async {
      final paths = <String>[];
      final api =
          ApiService(
              client: MockClient((request) async {
                paths.add(request.url.path);
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
      expect(paths, ['/api/parking/rates']);
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
