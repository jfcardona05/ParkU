import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parku_mobile/models/user_model.dart';
import 'package:parku_mobile/services/api_service.dart';
import 'package:parku_mobile/services/gate_service.dart';
import 'package:parku_mobile/screens/gate_screen.dart';

String token(int id, {bool expired = false}) =>
    'PARKU-DEMO:$id:${DateTime.now().add(Duration(minutes: expired ? -1 : 2)).millisecondsSinceEpoch}';
void main() {
  test('demo rejects invalid and expired tokens', () async {
    final gateway = DemoGateGateway();
    await expectLater(gateway.inspect('invalid'), throwsA(isA<ApiException>()));
    await expectLater(
      gateway.inspect(token(1, expired: true)),
      throwsA(isA<ApiException>()),
    );
  });
  test('retries are idempotent and consumed QR cannot be reused', () async {
    final gateway = DemoGateGateway();
    final preview = await gateway.inspect(token(7));
    final result = await gateway.confirm(
      preview,
      GateAction.entry,
      'request-1',
    );
    expect(
      await gateway.confirm(preview, GateAction.entry, 'request-1'),
      result,
    );
    await expectLater(
      gateway.inspect(preview.token),
      throwsA(isA<ApiException>()),
    );
    final another = await gateway.inspect(
      'PARKU-DEMO:7:${DateTime.now().add(const Duration(minutes: 3)).millisecondsSinceEpoch}',
    );
    await expectLater(
      gateway.confirm(another, GateAction.entry, 'request-2'),
      throwsA(isA<ApiException>()),
    );
    expect(
      await gateway.confirm(another, GateAction.exit, 'request-3'),
      contains('Salida'),
    );
  });
  test('exit without entry fails', () async {
    final gateway = DemoGateGateway();
    final preview = await gateway.inspect(token(8));
    await expectLater(
      gateway.confirm(preview, GateAction.exit, 'request'),
      throwsA(isA<ApiException>()),
    );
  });
  testWidgets('student cannot operate real gateway', (tester) async {
    final api = ApiService();
    api.setCurrentUser(
      UserModel(id: 1, name: 'Test', email: '', role: 'estudiante', balance: 0),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: GateScreen(
          apiService: api,
          gateway: const UnavailableGateGateway(),
        ),
      ),
    );
    expect(
      find.text('No tienes permiso para operar portería.'),
      findsOneWidget,
    );
    expect(find.text('Confirmar operación'), findsNothing);
  });
  testWidgets('scan validation does not register until confirmation', (
    tester,
  ) async {
    final gateway = DemoGateGateway();
    await tester.pumpWidget(
      MaterialApp(
        home: GateScreen(apiService: ApiService(), gateway: gateway),
      ),
    );
    await tester.enterText(find.byType(TextField), token(7));
    await tester.tap(find.text('Validar código'));
    await tester.pumpAndSettle();
    expect(find.text('Confirma los datos antes de registrar.'), findsOneWidget);
    expect(find.textContaining('Ingreso registrado'), findsNothing);
    await tester.tap(find.text('Confirmar operación'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ingreso registrado'), findsOneWidget);
    expect(find.text('Confirmar operación'), findsNothing);
  });
}
