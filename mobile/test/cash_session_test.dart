import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parku_mobile/models/user_model.dart';
import 'package:parku_mobile/services/api_service.dart';
import 'package:parku_mobile/screens/taquilla_screen.dart';
import 'package:parku_mobile/ui/park_theme.dart';
import 'package:parku_mobile/exports/cash_receipt.dart';

import 'support/cash_fixtures.dart';

http.Response json(Object value, [int status = 200]) => http.Response(
  jsonEncode(value),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
ApiService api(http.Client client) => ApiService(client: client)
  ..setToken('cash')
  ..setCurrentUser(
    UserModel(
      id: 3,
      name: 'Caja',
      email: 'caja@test.co',
      role: 'operador',
      balance: 0,
    ),
  );
Future<void> tap(WidgetTester tester, String label) async {
  final finder = find.text(label);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder input(String label) => find.widgetWithText(TextField, label);
void main() {
  test(
    'receipt escapes all user content and preserves closed monetary snapshot',
    () {
      final row = cashSession(closed: true)
        ..['notes'] = '<script>bad()</script>'
        ..['operator_name'] = 'Caja & Uno';
      final html = cashReceiptHtml(row);
      expect(html, contains('&lt;script&gt;bad()&lt;&#47;script&gt;'));
      expect(html, contains('Caja &amp; Uno'));
      expect(html, contains('22.000 COP'));
      expect(html, contains('8.000 COP'));
      expect(html, contains('No es una factura electrónica'));
      expect(html, isNot(contains('<script>bad()')));
    },
  );
  testWidgets(
    'open, recharge, cancel and close; report history exists only in Reports',
    (tester) async {
      var active = false, closed = false;
      var collected = 0;
      var closes = 0;
      final service = api(
        MockClient((r) async {
          expect(r.headers['Authorization'], 'Bearer cash');
          switch (r.url.path) {
            case '/api/admin/users':
              return json({
                'users': [
                  {
                    'id': 1,
                    'name': 'Juan',
                    'email': 'juan@test.co',
                    'role': 'estudiante',
                    'balance': collected,
                  },
                ],
              });
            case '/api/cash/current':
              final current = cashCurrent(active: active);
              if (active) {
                current['session'] = cashSession()
                  ..['recharge_total'] = collected
                  ..['expected_cash'] = 10000 + collected;
              }
              if (closed) {
                (current['points'] as List).first['available'] = false;
              }
              return json(current);
            case '/api/cash/open':
              expect(jsonDecode(r.body)['opening_amount'], 10000);
              active = true;
              return json({'success': true, 'session': cashSession()});
            case '/api/wallet/recharge':
              collected += 20000;
              return json({
                'success': true,
                'recharge': {
                  'amount': 20000,
                  'balance_after': 20000,
                  'point_name': point,
                  'reference': 'credit',
                  'created_at': '2026-11-17T15:00:00Z',
                },
              });
            case '/api/cash/1/close':
              closes++;
              expect(jsonDecode(r.body), {
                'counted_cash': 30000,
                'retained_cash': 8000,
                'notes': '',
              });
              active = false;
              closed = true;
              return json({
                'success': true,
                'session': cashSession(closed: true),
              });
            case '/api/cash/history':
              return json({
                'sessions': [cashSession(closed: true)],
                'has_more': false,
              });
            case '/api/admin/recharges':
              return json({
                'from': '2026-11-17',
                'through': '2026-11-17',
                'summary': {'total_amount': 20000, 'count': 1, 'user_count': 1},
                'recharges': [],
                'has_more': false,
              });
            default:
              throw StateError(r.url.path);
          }
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: parkTheme(),
          home: TaquillaScreen(apiService: service),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Historial de ingresos'), findsNothing);
      final recharge = find.widgetWithText(
        FilledButton,
        'Registrar abono en taquilla',
      );
      expect(tester.widget<FilledButton>(recharge).onPressed, isNull);
      await tester.enterText(input('Base de apertura para devueltas'), '10000');
      await tap(tester, 'Abrir caja');
      await tap(tester, 'Confirmar');
      await tester.enterText(
        input('Buscar usuario por nombre, documento o correo'),
        'Juan',
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await tap(tester, 'Juan');
      await tester.enterText(
        input('Importe recibido en efectivo (COP)'),
        '20000',
      );
      await tap(tester, 'Registrar abono en taquilla');
      expect(collected, 20000);
      expect(find.text('30.000 COP'), findsOneWidget);
      await tap(tester, 'Preparar cierre de caja');
      await tester.enterText(input('Efectivo total contado'), '30000');
      await tester.enterText(input('Base que queda para devueltas'), '8000');
      await tap(tester, 'Cerrar caja y generar comprobante');
      await tap(tester, 'Cancelar');
      expect(closes, 0);
      await tap(tester, 'Cerrar caja y generar comprobante');
      await tap(tester, 'Confirmar');
      expect(closes, 1);
      expect(find.text('Historial de ingresos'), findsNothing);
      await tap(tester, 'Abrir reportes de caja');
      expect(find.text('Cierres de caja'), findsOneWidget);
      expect(find.text('Historial de ingresos'), findsOneWidget);
      await tap(tester, 'Ver comprobante de cierre');
      expect(find.text('Efectivo a entregar: 22.000 COP'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'difference requires notes and cash load failure never enables recharge',
    (tester) async {
      var fail = false;
      var closes = 0;
      final service = api(
        MockClient((r) async {
          if (r.url.path == '/api/admin/users') return json({'users': []});
          if (r.url.path == '/api/cash/current') {
            return fail
                ? json({'message': 'Caja no disponible'}, 503)
                : json(cashCurrent());
          }
          closes++;
          return json({'success': true});
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: parkTheme(),
          home: TaquillaScreen(apiService: service),
        ),
      );
      await tester.pumpAndSettle();
      await tap(tester, 'Preparar cierre de caja');
      await tester.enterText(input('Efectivo total contado'), '20000');
      await tester.enterText(input('Base que queda para devueltas'), '1000');
      await tap(tester, 'Cerrar caja y generar comprobante');
      expect(
        find.text('Explica el faltante o sobrante antes de cerrar.'),
        findsOneWidget,
      );
      expect(closes, 0);
      fail = true;
      await tap(tester, 'Actualizar caja');
      final recharge = find.widgetWithText(
        FilledButton,
        'Registrar abono en taquilla',
      );
      expect(tester.widget<FilledButton>(recharge).onPressed, isNull);
      expect(tester.takeException(), isNull);
    },
  );
}
