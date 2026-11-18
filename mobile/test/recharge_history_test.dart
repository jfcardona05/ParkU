import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parku_mobile/models/user_model.dart';
import 'package:parku_mobile/screens/taquilla_screen.dart';
import 'package:parku_mobile/services/api_service.dart';
import 'package:parku_mobile/ui/park_theme.dart';
import 'package:parku_mobile/ui/park_shell.dart';
import 'package:parku_mobile/screens/taquilla_reports_screen.dart';
import 'package:parku_mobile/widgets/recharge_history_card.dart';

Map<String, dynamic> report({
  bool empty = false,
  bool more = false,
  int amount = 70000,
}) => {
  'from': '2026-11-16',
  'through': '2026-11-16',
  'summary': {
    'count': empty ? 0 : 2,
    'total_amount': empty ? 0 : amount,
    'user_count': empty ? 0 : 2,
  },
  'has_more': more,
  'recharges': empty
      ? []
      : [
          {
            'id': 1,
            'amount': 50000,
            'user_name': 'Ronaldo',
            'user_email': 'ronaldo@test.co',
            'operator_name': 'Caja principal',
            'point_name': 'Portería principal',
            'reference': '11111111-1111-4111-8111-111111111111',
            'created_at': '2026-11-17T04:59:00Z',
          },
        ],
};
http.Response response(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
ApiService apiFor(Future<http.Response> Function(http.Request) handler) =>
    ApiService(client: MockClient(handler))
      ..setToken('cash-token')
      ..setCurrentUser(
        UserModel(
          id: 3,
          name: 'Taquilla',
          email: 'cash@test.co',
          role: 'operador',
          balance: 0,
        ),
      );
Future<void> panel(
  WidgetTester tester,
  ApiService api, {
  int version = 0,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: parkTheme(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: RechargeHistoryCard(api: api, refreshVersion: version),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tapText(WidgetTester tester, String text) async {
  final target = find.text(text);
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  for (final width in [390.0, 834.0, 1440.0]) {
    for (final role in ['operador', 'estudiante', 'guard', 'admin']) {
      testWidgets('navigation for $role at $width preserves role scope', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final api = apiFor(
          (_) async => throw StateError('No personal API expected'),
        );
        api.setCurrentUser(api.currentUser!.copyWith(role: role));
        await tester.pumpWidget(
          MaterialApp(
            theme: parkTheme(),
            home: ParkShell(
              api: api,
              selected: 5,
              breadcrumb: 'Prueba',
              child: const Text('Contenido'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final compact = width >= 768 && width < 1100;
        Finder navigation(String label) =>
            compact ? find.byTooltip(label) : find.text(label);
        expect(
          navigation('Vehículos'),
          role == 'operador' ? findsNothing : findsOneWidget,
        );
        expect(
          navigation('Mi saldo'),
          role == 'operador' ? findsNothing : findsOneWidget,
        );
        expect(
          navigation('Panel de caja'),
          role == 'operador' ? findsOneWidget : findsNothing,
        );
        expect(
          navigation('Reportes'),
          role == 'operador' ? findsOneWidget : findsNothing,
        );
        expect(
          navigation('Portería'),
          ['guard', 'admin'].contains(role) ? findsWidgets : findsNothing,
        );
        expect(tester.takeException(), isNull);
      });
    }
    testWidgets(
      'cash reports at $width use real report totals and preserve filters',
      (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final requests = <Uri>[];
        final api = apiFor((r) async {
          requests.add(r.url);
          return response(report());
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: parkTheme(),
            home: TaquillaReportsScreen(apiService: api),
          ),
        );
        await tester.pumpAndSettle();
        expect(requests.single.path, '/api/admin/recharges');
        expect(find.text('Promedio por recarga'), findsOneWidget);
        expect(find.text('\$35.000 COP'), findsOneWidget);
        await tapText(tester, 'Mes');
        expect(requests.last.queryParameters['period'], 'month');
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'cashier personal navigation redirects to operations without wallet calls',
    (tester) async {
      final requests = <String>[];
      final api = apiFor((r) async {
        requests.add(r.url.path);
        if (r.url.path == '/api/admin/users') {
          return response({'users': []});
        }
        if (r.url.path == '/api/admin/recharges') {
          return response(report(empty: true));
        }
        throw StateError('Unexpected API: ${r.url.path}');
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => ParkShell.open(context, api, 1),
              child: const Text('Abrir'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      expect(find.byType(TaquillaScreen), findsOneWidget);
      expect(
        requests,
        containsAll(['/api/admin/users', '/api/admin/recharges']),
      );
      expect(
        requests.any((p) => p.contains('/wallet') || p.contains('/vehicles')),
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('large monthly totals fit a phone without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = apiFor((r) async => response(report(amount: 9000000000000)));
    await panel(tester, api);
    expect(find.text('\$9.000.000.000.000 COP'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'history uses authenticated report API; shows period total and Colombian timestamp',
    (tester) async {
      final requests = <Uri>[];
      final api = apiFor((r) async {
        expect(r.headers['Authorization'], 'Bearer cash-token');
        requests.add(r.url);
        return response(report());
      });
      await panel(tester, api);
      expect(requests.single.path, '/api/admin/recharges');
      expect(requests.single.queryParameters['period'], 'day');
      expect(find.text('\$70.000 COP'), findsOneWidget);
      expect(find.text('Ronaldo'), findsOneWidget);
      expect(find.text('Operador: Caja principal'), findsOneWidget);
      expect(find.text('16/11/2026 · 23:59 · Colombia'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'period search pagination and refresh use current filters and reset pages',
    (tester) async {
      final requests = <Uri>[];
      final api = apiFor((r) async {
        requests.add(r.url);
        return response(report(more: r.url.queryParameters['page'] == '0'));
      });
      await panel(tester, api);
      await tapText(tester, 'Semana');
      expect(requests.last.queryParameters['period'], 'week');
      await tapText(tester, 'Mes');
      expect(requests.last.queryParameters['period'], 'month');
      await tester.enterText(find.byType(TextField), 'ronaldo@test.co');
      await tapText(tester, 'Buscar recargas');
      expect(requests.last.queryParameters['search'], 'ronaldo@test.co');
      await tapText(tester, 'Siguiente');
      expect(requests.last.queryParameters['page'], '1');
      await tapText(tester, 'Actualizar historial');
      expect(requests.last.queryParameters['page'], '0');
      expect(requests.last.queryParameters['search'], 'ronaldo@test.co');
      await tester.ensureVisible(find.byTooltip('Limpiar búsqueda'));
      await tester.tap(find.byTooltip('Limpiar búsqueda'));
      await tester.pumpAndSettle();
      expect(requests.last.queryParameters['search'], '');
    },
  );
  testWidgets('reference date picker queries the selected calendar day', (
    tester,
  ) async {
    final requests = <Uri>[];
    final api = apiFor((r) async {
      requests.add(r.url);
      return response(report());
    });
    await panel(tester, api);
    await tester.tap(find.textContaining('Fecha:'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15').last);
    await tester.tap(find.text('Consultar'));
    await tester.pumpAndSettle();
    expect(requests.last.queryParameters['date'], endsWith('-15'));
    expect(requests, hasLength(2));
  });

  testWidgets(
    'errors do not display a false zero; retry recovers an empty period',
    (tester) async {
      var fail = true;
      final api = apiFor(
        (r) async => fail
            ? response({'message': 'Historial no disponible'}, 503)
            : response(report(empty: true)),
      );
      await panel(tester, api);
      expect(find.text('Historial no disponible'), findsOneWidget);
      expect(find.text('\$0 COP'), findsNothing);
      fail = false;
      await tapText(tester, 'Reintentar');
      expect(find.text('\$0 COP'), findsOneWidget);
      expect(
        find.text('No hay recargas para los filtros seleccionados.'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'successful recharge refreshes the history without losing the form',
    (tester) async {
      var recharged = false;
      var reports = 0;
      final api = apiFor((r) async {
        switch (r.url.path) {
          case '/api/admin/users':
            return response({
              'users': [
                {
                  'id': 1,
                  'name': 'Juan',
                  'email': 'juan@test.co',
                  'role': 'estudiante',
                  'balance': recharged ? 20000 : 0,
                },
              ],
            });
          case '/api/admin/recharges':
            reports++;
            return response(report(empty: !recharged, amount: 20000));
          case '/api/wallet/recharge':
            recharged = true;
            return response({
              'success': true,
              'recharge': {
                'amount': 20000,
                'balance_after': 20000,
                'point_name': 'Portería',
                'reference': 'test',
                'created_at': '2026-11-16T15:00:00Z',
              },
            });
          default:
            throw StateError(r.url.path);
        }
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: parkTheme(),
          home: TaquillaScreen(apiService: api),
        ),
      );
      await tester.pumpAndSettle();
      expect(reports, 1);
      await tester.enterText(find.byType(TextField).first, '20000');
      await tapText(tester, 'Registrar abono en taquilla');
      expect(recharged, isTrue);
      expect(reports, 2);
      await tapText(tester, 'Ver historial de recargas');
      expect(find.text('\$20.000 COP'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
