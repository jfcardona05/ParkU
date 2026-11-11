import 'package:flutter_test/flutter_test.dart';
import 'package:parku_mobile/services/api_service.dart';
import 'package:parku_mobile/services/gate_service.dart';
import 'package:parku_mobile/services/parking_service.dart';
import 'package:parku_mobile/services/vehicle_qr_service.dart';

void main() {
  test(
    'real API issues QR, records entry, rejects insufficient balance and charges once',
    () async {
      const studentEmail = String.fromEnvironment('LIVE_STUDENT_EMAIL');
      const guardEmail = String.fromEnvironment('LIVE_GUARD_EMAIL');
      const adminEmail = String.fromEnvironment('LIVE_ADMIN_EMAIL');
      const password = String.fromEnvironment('LIVE_TEST_PASSWORD');
      expect([
        studentEmail,
        guardEmail,
        adminEmail,
        password,
      ], everyElement(isNotEmpty));
      final student = ApiService();
      final guard = ApiService();
      final admin = ApiService();
      final cash = ApiService();
      try {
        expect((await student.login(studentEmail, password))['success'], true);
        expect((await guard.login(guardEmail, password))['success'], true);
        expect((await admin.login(adminEmail, password))['success'], true);
        expect(
          (await cash.login(
            'taquilla@usantotomas.edu.co',
            'caja123',
          ))['success'],
          true,
        );
        await admin.request('POST', '/api/admin/parking/settings', {
          'capacity': 2,
        });
        final rates = await ParkingService(student).getRates();
        final rate =
            rates.singleWhere((r) => r['vehicle_type'] == 'automovil')['amount']
                as int;
        expect(rate, greaterThan(0));

        expect(
          (await student.addVehicle(
            plate:
                'L${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}',
            type: 'automovil',
          ))['success'],
          true,
        );
        final vehicle = (await student.getVehicles()).single;
        final qr = ApiVehicleQrSource(student);
        final gate = ApiGateGateway(guard);
        final first = await qr.issue(vehicle);
        final replaced = await qr.issue(vehicle);
        await expectLater(
          gate.inspect(first.token),
          throwsA(
            isA<ApiException>().having((e) => e.code, 'code', 'QR_REVOKED'),
          ),
        );
        await expectLater(
          ApiGateGateway(student).inspect(replaced.token),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'status', 403),
          ),
        );

        final preview = await gate.inspect(replaced.token);
        expect(preview.allowedAction, GateAction.entry);
        final entryId = newGateRequestId();
        expect(
          await gate.confirm(preview, GateAction.entry, entryId),
          contains('Ingreso'),
        );
        expect(
          await gate.confirm(preview, GateAction.entry, entryId),
          contains('Ingreso'),
        );
        expect(
          (await ParkingService(student).getVehicles()).single.inside,
          true,
        );
        expect((await ParkingService(student).getOccupancy())['occupied'], 1);

        final exitQr = await qr.issue(vehicle);
        final exitPreview = await gate.inspect(exitQr.token);
        expect(exitPreview.allowedAction, GateAction.exit);
        final exitId = newGateRequestId();
        await expectLater(
          gate.confirm(exitPreview, GateAction.exit, exitId),
          throwsA(
            isA<ApiException>().having(
              (e) => e.code,
              'code',
              'INSUFFICIENT_BALANCE',
            ),
          ),
        );
        expect(await student.getBalance(), 0);
        expect(await student.getHistory(), isEmpty);
        expect(
          (await ParkingService(student).getVehicles()).single.inside,
          true,
        );

        expect(
          (await cash.recharge(
            amount: rate * 2,
            pointName: 'Punto 1 - Portería Principal USTA',
            userId: student.currentUser!.id,
          ))['success'],
          true,
        );
        final receipt = await gate.confirm(
          exitPreview,
          GateAction.exit,
          exitId,
        );
        expect(receipt, contains('Salida'));
        expect(
          await gate.confirm(exitPreview, GateAction.exit, exitId),
          receipt,
        );
        expect(await student.getBalance(), rate);
        final history = await student.getHistory();
        final charges = history.where(
          (tx) => tx.type == 'COBRO_ESTACIONAMIENTO',
        );
        expect(charges, hasLength(1));
        expect(charges.single.amount, rate);
        expect(charges.single.parkingRateLabel, isNotEmpty);
        expect(
          (await ParkingService(student).getVehicles()).single.inside,
          false,
        );
        expect((await ParkingService(student).getOccupancy())['occupied'], 0);
        final accesses = await ParkingService(student).getHistory();
        expect(accesses.operations.map((op) => op['action']), [
          'exit',
          'entry',
        ]);
        expect((await ParkingService(guard).getHistory()).operations, isEmpty);
      } finally {
        await student.logout();
        await guard.logout();
        await admin.logout();
        await cash.logout();
      }
    },
    skip: !const bool.fromEnvironment('LIVE_PARKING_API'),
  );
}
