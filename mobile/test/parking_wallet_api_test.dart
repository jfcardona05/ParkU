import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parku_mobile/models/transaction_model.dart';
import 'package:parku_mobile/screens/wallet_screen.dart';
import 'package:parku_mobile/services/api_service.dart';
import 'package:parku_mobile/services/parking_service.dart';
import 'package:parku_mobile/widgets/balance_card.dart';

void main() {
  testWidgets(
    'live wallet data renders positive server debit, tariff and vehicle state',
    (tester) async {
      var inside = true;
      var charged = false;
      final api = ApiService(
        client: MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer student');
          final body = switch (request.url.path) {
            '/api/wallet/balance' => {'balance': charged ? 5000 : 10000},
            '/api/wallet/history' => {
              'transactions': [
                if (charged)
                  {
                    'id': 1,
                    'type': 'COBRO_ESTACIONAMIENTO',
                    'amount': 5000,
                    'point_name': 'Portería',
                    'balance_after': 5000,
                    'parking_rate_label': '5000 COP por hora iniciada',
                  },
              ],
            },
            '/api/vehicles' => {
              'vehicles': [
                {'id': 7, 'plate': 'ABC123', 'type': 'automovil'},
              ],
            },
            '/api/vehicles/7/parking' => {
              'vehicle_id': 7,
              'parking_state': inside ? 'INSIDE' : 'OUTSIDE',
              'entered_at': inside ? '2026-11-10T12:00:00Z' : null,
            },
            _ => throw StateError(request.url.path),
          };
          return jsonResponse(jsonEncode(body), 200);
        }),
      )..setToken('student');
      await tester.pumpWidget(MaterialApp(home: WalletScreen(apiService: api)));
      await tester.pumpAndSettle();
      expect(find.text('Tienes un ingreso activo.'), findsOneWidget);

      inside = false;
      charged = true;
      await tester.tap(find.byTooltip('Actualizar saldo y movimientos'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<BalanceCard>(find.byType(BalanceCard)).balance,
        5000,
      );
      expect(find.text('Sin ingreso activo.'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Tarifa aplicada: 5000 COP por hora iniciada'),
        100,
      );
      expect(find.text('−\$5.000 COP'), findsOneWidget);
    },
  );

  test('legacy recharges keep parsing without a parking tariff', () {
    final movement = TransactionModel.fromJson({
      'id': 1,
      'amount': 10000,
      'type': 'RECARGA_PRESENCIAL',
    });
    expect(movement.parkingRateLabel, isNull);
    expect(movement.type, TransactionModel.inPersonRechargeType);
  });

  test(
    'parking history preserves server pagination and authentication',
    () async {
      final api = ApiService(
        client: MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer student');
          expect(request.url.queryParameters['before_id'], '42');
          return jsonResponse('{"operations":[],"next_before_id":null}', 200);
        }),
      )..setToken('student');
      expect(
        (await ParkingService(api).getHistory(beforeId: 42)).operations,
        isEmpty,
      );
    },
  );
}

http.Response jsonResponse(String body, int status) => http.Response(
  body,
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
