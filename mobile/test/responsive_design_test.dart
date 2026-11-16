import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parku_mobile/models/user_model.dart';
import 'package:parku_mobile/models/vehicle_model.dart';
import 'package:parku_mobile/screens/login_screen.dart';
import 'package:parku_mobile/screens/register_screen.dart';
import 'package:parku_mobile/screens/dashboard_screen.dart';
import 'package:parku_mobile/screens/vehicles_screen.dart';
import 'package:parku_mobile/screens/add_vehicle_screen.dart';
import 'package:parku_mobile/screens/vehicle_qr_screen.dart';
import 'package:parku_mobile/screens/wallet_screen.dart';
import 'package:parku_mobile/screens/parking_screen.dart';
import 'package:parku_mobile/screens/gate_screen.dart';
import 'package:parku_mobile/screens/taquilla_screen.dart';
import 'package:parku_mobile/services/api_service.dart';
import 'package:parku_mobile/services/gate_service.dart';
import 'package:parku_mobile/services/vehicle_qr_service.dart';
import 'package:parku_mobile/ui/park_theme.dart';

final vehicle = VehicleModel(
  id: 7,
  plate: 'KTU482',
  type: 'automovil',
  brandModel: 'Chevrolet Onix',
  createdAt: '',
);

ApiService fixture({String role = 'estudiante'}) {
  final api = ApiService(
    client: MockClient((request) async {
      final Object response = switch (request.url.path) {
        '/api/vehicles' => {
          'vehicles': [vehicle.toJson()],
        },
        '/api/vehicles/7/parking' => {
          'vehicle_id': 7,
          'parking_state': 'OUTSIDE',
          'visit_id': null,
          'entered_at': null,
        },
        '/api/parking/occupancy' => {
          'success': true,
          'available': 38,
          'capacity': 80,
          'occupied': 42,
        },
        '/api/parking/rates' => {
          'rates': [
            {
              'vehicle_type': 'moto',
              'amount': 4000,
              'block_seconds': 3600,
              'minimum_blocks': 1,
            },
            {
              'vehicle_type': 'automovil',
              'amount': 5000,
              'block_seconds': 3600,
              'minimum_blocks': 1,
            },
          ],
        },
        '/api/parking/history' => {
          'operations': [
            {
              'operation_id': 2,
              'plate': 'KTU482',
              'action': 'exit',
              'occurred_at': '2026-11-16T12:00:00Z',
              'charge': {
                'amount': 5000,
                'balance_after': 15000,
                'parking_rate_label': '5000 COP / hora iniciada',
              },
            },
          ],
          'next_before_id': null,
        },
        '/api/wallet/balance' => {'balance': 15000},
        '/api/wallet/history' => {
          'transactions': [
            {
              'id': 2,
              'type': 'RECARGA_PRESENCIAL',
              'amount': 20000,
              'point_name': 'Portería Principal',
              'balance_after': 20000,
              'reference': 'PREVIEW-RECARGA',
              'created_at': '2026-11-16T10:00:00Z',
            },
            {
              'id': 1,
              'type': 'COBRO_ESTACIONAMIENTO',
              'amount': 5000,
              'point_name': 'Portería',
              'balance_after': 15000,
              'parking_rate_label': '5000 COP / hora iniciada',
              'created_at': '2026-11-16T12:00:00Z',
            },
          ],
        },
        '/api/admin/users' => {
          'users': [
            {
              'id': 1,
              'name': 'Ronaldo Mosquera',
              'email': 'preview@example.test',
              'role': 'estudiante',
              'balance': 15000,
            },
          ],
        },
        _ => throw StateError(
          'Unexpected preview endpoint: ${request.url.path}',
        ),
      };
      return http.Response(
        jsonEncode(response),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }),
  );
  api.setToken('test-session');
  api.setCurrentUser(
    UserModel(
      id: 1,
      name: 'Ronaldo Mosquera',
      email: 'preview@example.test',
      role: role,
      balance: 15000,
    ),
  );
  return api;
}

class PreviewQr implements VehicleQrSource {
  @override
  bool get isDemo => false;
  @override
  Future<VehicleQr> issue(VehicleModel vehicle) async => VehicleQr(
    vehicleId: vehicle.id,
    token: 'VISUAL-TEST-ONLY-NOT-AN-ACCESS-TOKEN',
    expiresAt: DateTime.utc(2099),
  );
}

void main() {
  setUpAll(() async {
    if (const bool.fromEnvironment('CAPTURE_UI')) {
      final font = FontLoader('Roboto');
      final bytes = await File('build/preview-font.ttf').readAsBytes();
      font.addFont(Future.value(ByteData.sublistView(bytes)));
      await font.load();
      final icons = FontLoader('MaterialIcons');
      icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
    }
  });
  const sizes = [(390.0, 844.0), (834.0, 1194.0), (1440.0, 1000.0)];
  for (final size in sizes) {
    for (final page in [
      'login',
      'register',
      'home',
      'vehicles',
      'add-vehicle',
      'qr',
      'wallet',
      'parking',
      'gate',
      'cash',
    ]) {
      testWidgets('responsive $page at ${size.$1}', (tester) async {
        tester.view.physicalSize = Size(size.$1, size.$2);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final api = fixture(
          role: page == 'cash'
              ? 'operador'
              : page == 'gate'
              ? 'guard'
              : 'estudiante',
        );
        if (page == 'login' || page == 'register') api.setCurrentUser(null);
        final Widget screen = switch (page) {
          'login' => LoginScreen(apiService: api),
          'register' => RegisterScreen(apiService: api),
          'home' => DashboardScreen(apiService: api),
          'vehicles' => VehiclesScreen(apiService: api),
          'add-vehicle' => AddVehicleScreen(apiService: api),
          'qr' => VehicleQrScreen(
            vehicle: vehicle,
            source: PreviewQr(),
            apiService: api,
          ),
          'wallet' => WalletScreen(apiService: api),
          'parking' => ParkingScreen(apiService: api),
          'gate' => GateScreen(apiService: api, gateway: ApiGateGateway(api)),
          _ => TaquillaScreen(apiService: api),
        };
        final capture = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: parkTheme(),
            home: RepaintBoundary(key: capture, child: screen),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: '$page must fit the viewport without layout exceptions',
        );
        if (const bool.fromEnvironment('CAPTURE_UI')) {
          final boundary =
              capture.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 1);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final directory = Directory('build/ui-previews');
            await directory.create(recursive: true);
            await File(
              '${directory.path}/$page-${size.$1.toInt()}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      });
    }
  }
  testWidgets('mobile navigation preserves real wallet and parking queries', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: parkTheme(),
        home: DashboardScreen(apiService: fixture()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mi saldo'));
    await tester.pumpAndSettle();
    expect(find.text('Tu saldo, al día'), findsOneWidget);
    expect(find.text('\$15.000'), findsOneWidget);
    await tester.tap(find.text('Parqueadero'));
    await tester.pumpAndSettle();
    expect(find.text('Así está el parqueadero'), findsOneWidget);
    expect(find.text('38 de 80'), findsOneWidget);
    await tester.tap(find.text('Vehículos'));
    await tester.pumpAndSettle();
    expect(find.text('Tus vehículos'), findsOneWidget);
    expect(find.text('KTU482'), findsOneWidget);
  });
}
