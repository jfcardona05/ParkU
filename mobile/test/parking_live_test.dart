import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:parku_mobile/services/api_service.dart';
import 'package:parku_mobile/services/gate_service.dart';
import 'package:parku_mobile/services/parking_service.dart';
import 'package:parku_mobile/services/vehicle_qr_service.dart';

void main() {
  test(
    'real API: prepaid daily QR, phone card, entry/exit and transfer without duplicate debits',
    () async {
      const studentEmail = String.fromEnvironment('LIVE_STUDENT_EMAIL');
      const guardEmail = String.fromEnvironment('LIVE_GUARD_EMAIL');
      const password = String.fromEnvironment('LIVE_TEST_PASSWORD');
      expect([studentEmail, guardEmail, password], everyElement(isNotEmpty));
      final student = ApiService(),
          guard = ApiService(),
          cash = ApiService(),
          receiver = ApiService();
      try {
        expect((await student.login(studentEmail, password))['success'], true);
        expect((await guard.login(guardEmail, password))['success'], true);
        expect(
          (await cash.login(
            'taquilla@usantotomas.edu.co',
            'caja123',
          ))['success'],
          true,
        );
        final cashState = await cash.request('GET', '/api/cash/current');
        var cashDay = cashState['session'] as Map<String, dynamic>?;
        if (cashDay == null) {
          final info = (cashState['points'] as List)
              .cast<Map<String, dynamic>>()
              .firstWhere((p) => p['available'] == true);
          cashDay =
              (await cash.request('POST', '/api/cash/open', {
                    'point_name': info['point_name'],
                    'opening_amount': info['opening_amount'] ?? 0,
                  }))['session']
                  as Map<String, dynamic>;
        }
        final cashPoint = cashDay['point_name'] as String;
        final rates = await ParkingService(student).getRates();
        final rate =
            rates.singleWhere((r) => r['vehicle_type'] == 'automovil')['amount']
                as int;
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
        final quote = await qr.lookup(vehicle);
        expect(quote.qr, isNull);
        expect(quote.amount, rate);
        expect(await student.getBalance(), 0);
        await expectLater(
          qr.issue(vehicle),
          throwsA(
            isA<ApiException>().having(
              (e) => e.code,
              'code',
              'INSUFFICIENT_BALANCE',
            ),
          ),
        );
        expect(await student.getHistory(), isEmpty);
        expect(
          (await cash.recharge(
            amount: rate * 2,
            pointName: cashPoint,
            userId: student.currentUser!.id,
          ))['success'],
          true,
        );
        final first = await qr.issue(vehicle),
            repeated = await qr.issue(vehicle);
        expect(repeated.token, first.token);
        expect(first.daily, true);
        expect(await student.getBalance(), rate);
        final phone = await http.get(Uri.parse(first.scanUrl!));
        expect(phone.statusCode, 200);
        expect(phone.body, contains(vehicle.plate));
        expect(phone.body, contains(student.currentUser!.name));
        expect(phone.body, contains('Automóvil'));
        expect(phone.body, isNot(contains(student.currentUser!.email)));
        final gate = ApiGateGateway(guard);
        await expectLater(
          ApiGateGateway(student).inspect(first.token),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'status', 403),
          ),
        );
        final preview = await gate.inspect(first.scanUrl!);
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
        final exit = await gate.inspect(first.scanUrl!);
        expect(exit.allowedAction, GateAction.exit);
        final exitId = newGateRequestId();
        expect(
          await gate.confirm(exit, GateAction.exit, exitId),
          contains('Salida'),
        );
        expect(await student.getBalance(), rate);
        expect(
          (await student.getHistory()).where(
            (tx) => tx.type == 'COBRO_ESTACIONAMIENTO',
          ),
          hasLength(1),
        );
        expect((await qr.lookup(vehicle)).qr!.token, first.token);
        final email =
            'receiver-${DateTime.now().microsecondsSinceEpoch}@test.co';
        final registered = await http.post(
          Uri.parse('${ApiService.baseUrl}/api/auth/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'name': 'Live receiver',
            'email': email,
            'password': 'pass123',
          }),
        );
        expect(registered.statusCode, 201);
        expect((await receiver.login(email, 'pass123'))['success'], true);
        final key = 'live-${DateTime.now().microsecondsSinceEpoch}';
        final sent = await student.transfer(
          recipientEmail: email,
          amount: 1000,
          requestId: key,
        );
        final retry = await student.transfer(
          recipientEmail: email,
          amount: 1000,
          requestId: key,
        );
        expect(retry['transfer_id'], sent['transfer_id']);
        expect(retry['replayed'], true);
        expect(await student.getBalance(), rate - 1000);
        expect(await receiver.getBalance(), 1000);
        expect(
          (await receiver.getHistory()).single.type,
          'TRANSFERENCIA_RECIBIDA',
        );
        expect(
          (await student.getHistory()).where(
            (tx) => tx.type == 'TRANSFERENCIA_ENVIADA',
          ),
          hasLength(1),
        );
      } finally {
        await student.logout();
        await guard.logout();
        await cash.logout();
        await receiver.logout();
      }
    },
    skip: !const bool.fromEnvironment('LIVE_PARKING_API'),
  );
}
