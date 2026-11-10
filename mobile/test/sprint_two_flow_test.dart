import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parku_mobile/main.dart';
import 'package:parku_mobile/models/transaction_model.dart';
import 'package:parku_mobile/models/vehicle_model.dart';
import 'package:parku_mobile/screens/gate_screen.dart';
import 'package:parku_mobile/screens/vehicle_qr_screen.dart';
import 'package:parku_mobile/screens/wallet_screen.dart';
import 'package:parku_mobile/services/api_service.dart';
import 'package:parku_mobile/services/gate_service.dart';
import 'package:parku_mobile/services/vehicle_qr_service.dart';
import 'package:parku_mobile/widgets/balance_card.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ParkingFixture {
  static const initialBalance = 10000;
  static const fee = 2500;
  var status = ParkingStatus.outside;
  TransactionModel? charge;

  int get balance => charge?.balanceAfter ?? initialBalance;

  http.Response respond(http.Request request) {
    final path = request.url.path;
    if (path != '/api/auth/login' &&
        request.headers['Authorization'] != 'Bearer fixture-session') {
      return http.Response('{"message":"Sesión requerida"}', 401);
    }
    final body = switch (path) {
      '/api/auth/login' => {
        'token': 'fixture-session',
        'user': {
          'id': 1,
          'name': 'Cuenta de prueba',
          'role': 'estudiante',
          'balance': balance,
        },
      },
      '/api/vehicles' => {
        'vehicles': [
          {'id': 7, 'plate': 'ABC123', 'type': 'automovil'},
        ],
      },
      '/api/wallet/balance' => {'balance': balance},
      '/api/wallet/history' => {'transactions': []},
      _ => throw StateError('Solicitud inesperada: $path'),
    };
    return http.Response(jsonEncode(body), 200);
  }
}

// Test-only adapter models the server response for a confirmed operation.
class FixtureGateGateway extends DemoGateGateway {
  final ParkingFixture fixture;
  FixtureGateGateway(this.fixture);

  @override
  Future<String> confirm(
    GatePreview preview,
    GateAction action,
    String requestId,
  ) async {
    final result = await super.confirm(preview, action, requestId);
    if (action == GateAction.entry) {
      fixture.status = ParkingStatus.inside;
    } else {
      fixture.status = ParkingStatus.outside;
      fixture.charge ??= TransactionModel(
        id: 1,
        type: TransactionModel.parkingChargeType,
        amount: -ParkingFixture.fee,
        pointName: 'Portería de prueba',
        reference: 'SALIDA-PRUEBA',
        balanceAfter: ParkingFixture.initialBalance - ParkingFixture.fee,
        createdAt: '',
        parkingRateLabel: '2.500 COP de prueba',
      );
    }
    return result;
  }
}

class FixtureWalletApi extends ApiService {
  final ParkingFixture fixture;
  FixtureWalletApi(this.fixture)
    : super(client: MockClient((request) async => fixture.respond(request)));

  @override
  Future<List<TransactionModel>> getHistory() async {
    final existing = await super.getHistory();
    return [if (fixture.charge case final charge?) charge, ...existing];
  }
}

class CapturingQrSource extends DemoVehicleQrSource {
  late String issuedToken;

  @override
  Future<VehicleQr> issue(VehicleModel vehicle) async {
    final qr = await super.issue(vehicle);
    issuedToken = qr.token;
    return qr;
  }
}

Future<String> showVehicleQr(WidgetTester tester, VehicleModel vehicle) async {
  final source = CapturingQrSource();
  await tester.pumpWidget(
    MaterialApp(
      home: VehicleQrScreen(vehicle: vehicle, source: source),
    ),
  );
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pumpAndSettle();
  expect(find.text('QR · ABC123'), findsOneWidget);
  expect(find.byType(QrImageView), findsOneWidget);
  return source.issuedToken;
}

Future<void> validateQr(WidgetTester tester, String code) async {
  await tester.enterText(find.byType(TextField), code);
  await tester.tap(find.text('Validar código'));
  await tester.pumpAndSettle();
}

Future<void> confirmGateOperation(WidgetTester tester) async {
  final confirm = find.text('Confirmar operación');
  await tester.ensureVisible(confirm);
  await tester.tap(confirm);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('login, QR, entry, QR reuse rejection, exit and wallet update', (
    tester,
  ) async {
    final fixture = ParkingFixture();
    final api = FixtureWalletApi(fixture);
    final gate = FixtureGateGateway(fixture);
    await tester.pumpWidget(ParkUApp(apiService: api));
    await tester.enterText(find.byType(TextField).first, 'park@example.test');
    await tester.enterText(find.byType(TextField).last, 'fixture-password');
    final submit = find.text('Ingresar a mi Cuenta');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(api.currentUser?.name, 'Cuenta de prueba');

    final vehicle = (await api.getVehicles()).single;
    final entryQr = await showVehicleQr(tester, vehicle);
    await tester.pumpWidget(
      MaterialApp(
        home: GateScreen(apiService: api, gateway: gate),
      ),
    );
    await tester.pumpAndSettle();
    await validateQr(tester, entryQr);
    expect(fixture.status, ParkingStatus.outside);
    await confirmGateOperation(tester);
    expect(find.textContaining('Ingreso registrado'), findsOneWidget);
    expect(fixture.status, ParkingStatus.inside);
    expect(fixture.charge, isNull);

    await validateQr(tester, entryQr);
    expect(find.text('Este QR ya fue utilizado.'), findsOneWidget);
    expect(find.text('Confirmar operación'), findsNothing);

    final exitQr = await showVehicleQr(tester, vehicle);
    expect(exitQr, isNot(entryQr));
    await tester.pumpWidget(
      MaterialApp(
        home: GateScreen(apiService: api, gateway: gate),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salida'));
    await tester.pumpAndSettle();
    await validateQr(tester, exitQr);
    expect(fixture.charge, isNull);
    await confirmGateOperation(tester);
    expect(find.textContaining('Salida registrado'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: WalletScreen(
          apiService: api,
          loadParkingStatus: () async => fixture.status,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<BalanceCard>(find.byType(BalanceCard)).balance, 7500);
    expect(find.text('Sin ingreso activo.'), findsOneWidget);
    expect(find.text('Cobro de estacionamiento'), findsOneWidget);
    expect(find.text('Tarifa aplicada: 2.500 COP de prueba'), findsOneWidget);
    expect(find.text('−\$2.500 COP'), findsOneWidget);
    expect(find.text('Ref. SALIDA-PRUEBA'), findsOneWidget);
  });
}
