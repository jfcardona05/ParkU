import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parku_mobile/screens/parking_screen.dart';
import 'package:parku_mobile/services/api_service.dart';

void main() {
  testWidgets(
    'occupancy failure leaves rates and history usable and pagination retries safely',
    (tester) async {
      final cursors = <String?>[];
      var failedOnce = false;
      final api = ApiService(
        client: MockClient((request) async {
          if (request.url.path == '/api/parking/occupancy') {
            return http.Response(
              '{"message":"Capacidad pendiente","code":"PARKING_NOT_CONFIGURED"}',
              503,
            );
          }
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
      expect(find.text('Capacidad pendiente'), findsOneWidget);
      expect(find.text('Moto'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Cargar más accesos'), 150);
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
