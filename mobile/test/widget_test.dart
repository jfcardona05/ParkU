import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parku_mobile/main.dart';
import 'package:parku_mobile/services/api_service.dart';

void main() {
  testWidgets('empty login shows validation without a network request', (
    tester,
  ) async {
    final api = ApiService(
      client: MockClient(
        (_) async => throw StateError('Unexpected network call'),
      ),
    );
    await tester.pumpWidget(ParkUApp(apiService: api));
    final submit = find.text('Ingresar a mi Cuenta');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();
    expect(
      find.text('Por favor ingresa tu correo y contraseña.'),
      findsOneWidget,
    );
  });
  testWidgets('rejected credentials stay on login and display the API error', (
    tester,
  ) async {
    final api = ApiService(
      client: MockClient(
        (_) async => http.Response('{"message":"Credenciales invalidas"}', 401),
      ),
    );
    await tester.pumpWidget(ParkUApp(apiService: api));
    await tester.enterText(find.byType(TextField).first, 'one@test.co');
    await tester.enterText(find.byType(TextField).last, 'wrong');
    final submit = find.text('Ingresar a mi Cuenta');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('Credenciales invalidas'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
    expect(api.currentUser, isNull);
  });
}
