import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:parku_mobile/models/vehicle_model.dart';
import 'package:parku_mobile/services/vehicle_qr_service.dart';
import 'package:parku_mobile/screens/vehicle_qr_screen.dart';

class Source implements VehicleQrSource {
  final response = Completer<VehicleQr>();
  @override
  bool get isDemo => false;
  @override
  Future<VehicleQr> issue(VehicleModel vehicle) => response.future;
}

final vehicle = VehicleModel(
  id: 7,
  plate: 'ABC123',
  type: 'automovil',
  brandModel: '',
  createdAt: '',
);
void main() {
  testWidgets('loading then QR of selected vehicle', (tester) async {
    final source = Source();
    await tester.pumpWidget(
      MaterialApp(
        home: VehicleQrScreen(vehicle: vehicle, source: source),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    source.response.complete(
      VehicleQr(
        vehicleId: 7,
        token: 'opaque-token',
        expiresAt: DateTime.now().add(const Duration(minutes: 2)),
      ),
    );
    await tester.pump();
    expect(find.text('QR · ABC123'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('expired QR is never rendered', (tester) async {
    final source = Source();
    source.response.complete(
      VehicleQr(vehicleId: 7, token: 'expired', expiresAt: DateTime(2000)),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: VehicleQrScreen(vehicle: vehicle, source: source),
      ),
    );
    await tester.pump();
    expect(find.byType(QrImageView), findsNothing);
    expect(find.text('QR vencido. Genera uno nuevo.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('wrong vehicle is rejected', (tester) async {
    final source = Source();
    source.response.complete(
      VehicleQr(
        vehicleId: 8,
        token: 'wrong',
        expiresAt: DateTime.now().add(const Duration(minutes: 1)),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: VehicleQrScreen(vehicle: vehicle, source: source),
      ),
    );
    await tester.pump();
    expect(
      find.text('El QR recibido no corresponde al vehículo.'),
      findsOneWidget,
    );
    expect(find.byType(QrImageView), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('unavailable service displays recoverable error', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VehicleQrScreen(
          vehicle: vehicle,
          source: const UnavailableVehicleQrSource(),
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('aún no está disponible'), findsOneWidget);
    await tester.tap(find.text('Generar nuevo QR'));
    await tester.pump();
    expect(find.textContaining('aún no está disponible'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
