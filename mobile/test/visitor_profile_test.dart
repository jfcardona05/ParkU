import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parku_mobile/models/user_model.dart';
import 'package:parku_mobile/services/api_service.dart';
import 'package:parku_mobile/screens/profile_screen.dart';
import 'package:parku_mobile/widgets/visitor_sale_form.dart';
import 'package:parku_mobile/ui/park_theme.dart';

http.Response json(Object x) => http.Response(
  jsonEncode(x),
  200,
  headers: {'content-type': 'application/json'},
);
ApiService api(Future<http.Response> Function(http.Request) handler) =>
    ApiService(client: MockClient(handler))
      ..setToken('test')
      ..setCurrentUser(
        UserModel(
          id: 3,
          name: 'Juan',
          email: 'juan@test.co',
          role: 'estudiante',
          balance: 10000,
          documentType: 'CC',
          documentNumber: '100003',
        ),
      );
void main() {
  test('transfer identifies recipient by CC/TI, never email', () async {
    final service = api((r) async {
      expect(jsonDecode(r.body), {
        'recipient_document_type': 'TI',
        'recipient_document_number': '1234567',
        'amount': 3000,
        'request_id': 'key',
      });
      return json({'balance_after': 7000});
    });
    await service.transfer(
      recipientDocumentType: 'TI',
      recipientDocumentNumber: '1234567',
      amount: 3000,
      requestId: 'key',
    );
    expect(service.currentUser!.balance, 7000);
  });
  test('cashier user search encodes name safely', () async {
    final service = api((r) async {
      expect(r.url.path, '/api/admin/users');
      expect(r.url.queryParameters['search'], 'Juan & María');
      return json({'users': []});
    });
    expect(await service.getUsers(search: 'Juan & María'), isEmpty);
  });
  for (final width in [390.0, 834.0, 1440.0]) {
    testWidgets('profile saves self data and retains design at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var posts = 0;
      final service = api((r) async {
        posts++;
        final body = jsonDecode(r.body) as Map;
        expect(body['current_password'], 'pass123');
        expect(body.containsKey('role'), false);
        expect(body['document_type'], 'CC');
        return json({
          'user': {
            'id': 3,
            'name': body['name'],
            'email': 'juan@test.co',
            'role': 'estudiante',
            'balance': 10000,
            'document_type': 'CC',
            'document_number': '100003',
          },
        });
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: parkTheme(),
          home: ProfileScreen(apiService: service),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).first,
        'Juan actualizado',
      );
      final password = find.widgetWithText(TextFormField, 'Contraseña actual');
      await tester.ensureVisible(password);
      await tester.enterText(password, 'pass123');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      final save = find.text('Guardar cambios');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(posts, 1);
      expect(service.currentUser!.name, 'Juan actualizado');
      expect(find.text('Datos actualizados'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('visitor cash confirmation can be cancelled without sale', (
    tester,
  ) async {
    var sales = 0;
    final service = api((r) async {
      if (r.method == 'POST') sales++;
      return json({'amount': 5000, 'service_date': '2030-01-01'});
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: parkTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: VisitorSaleForm(
              api: service,
              enabled: true,
              pointName: 'Punto 1 - Portería Principal USTA',
              onBusy: (_) {},
              onSold: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Visitante');
    await tester.enterText(find.byType(TextFormField).at(1), 'ABC123');
    final button = find.text('Cobrar pase y generar QR');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('Confirmar pago recibido'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(sales, 0);
    expect(service.pendingVisitorSale, isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
