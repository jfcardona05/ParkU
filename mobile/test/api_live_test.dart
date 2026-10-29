import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:parku_mobile/services/api_service.dart';

void main() {
  test(
    'Flutter talks to Spring Boot: login, vehicles, balance and cash recharge',
    () async {
      final email = 'live-${DateTime.now().microsecondsSinceEpoch}@test.co';
      final registration = await http.post(
        Uri.parse('${ApiService.baseUrl}/api/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': 'Prueba de integración',
          'email': email,
          'password': 'pass123',
        }),
      );
      expect(registration.statusCode, 201);
      final user = ApiService();
      final cash = ApiService();
      expect((await user.login(email, 'pass123'))['success'], true);
      expect(await user.getBalance(), 0);
      expect(
        (await user.addVehicle(
          plate:
              'T${DateTime.now().millisecondsSinceEpoch.toString().substring(4)}',
          type: 'moto',
        ))['success'],
        true,
      );
      expect(await user.getVehicles(), hasLength(1));
      expect(
        (await cash.login('taquilla@usantotomas.edu.co', 'caja123'))['success'],
        true,
      );
      final people = await cash.getUsers();
      final beneficiary = people.singleWhere((u) => u.email == email);
      expect(
        (await cash.recharge(
          amount: 10000,
          pointName: 'Punto 2 - Cafetería Central USTA',
          userId: beneficiary.id,
        ))['success'],
        true,
      );
      expect(await user.getBalance(), 10000);
      final history = await user.getHistory();
      expect(history, hasLength(1));
      expect(history.single.amount, 10000);
      expect(history.single.reference, isNotEmpty);
      await user.logout();
      await cash.logout();
    },
    skip: !const bool.fromEnvironment('LIVE_API'),
  );
}
