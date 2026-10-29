import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parku_mobile/services/api_service.dart';

void main() {
  test(
    'login retains session; taquilla request includes bearer token',
    () async {
      final api = ApiService(
        client: MockClient((request) async {
          if (request.url.path == '/api/auth/login') {
            return http.Response(
              jsonEncode({
                'token': 'session',
                'user': {
                  'id': 1,
                  'name': 'Caja',
                  'email': 'cash@test.co',
                  'role': 'operador',
                  'balance': 0,
                },
              }),
              200,
            );
          }
          expect(request.url.path, '/api/admin/users');
          expect(request.headers['Authorization'], 'Bearer session');
          return http.Response('{"users":[]}', 200);
        }),
      );
      expect((await api.login('cash@test.co', 'pass123'))['success'], true);
      expect(await api.getUsers(), isEmpty);
    },
  );
  test(
    '401 clears old session and does not return a fake zero balance',
    () async {
      final api = ApiService(
        client: MockClient(
          (_) async => http.Response(
            '{"message":"Sesión vencida"}',
            401,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );
      api.setToken('expired');
      await expectLater(api.getBalance(), throwsA(isA<ApiException>()));
      expect(api.token, isNull);
      expect(api.currentUser, isNull);
    },
  );
  test('recharge sends beneficiary and amount to protected API', () async {
    final api = ApiService(
      client: MockClient((request) async {
        expect(request.url.path, '/api/wallet/recharge');
        expect(request.headers['Authorization'], 'Bearer cash-session');
        expect(jsonDecode(request.body), {
          'amount': 5000,
          'point_name': 'Punto 1 - Portería Principal USTA',
          'user_id': 2,
        });
        return http.Response(
          '{"success":true,"recharge":{"balance_after":6000}}',
          200,
        );
      }),
    );
    api.setToken('cash-session');
    expect(
      (await api.recharge(
        amount: 5000,
        pointName: 'Punto 1 - Portería Principal USTA',
        userId: 2,
      ))['success'],
      true,
    );
  });
  test('network errors are reported instead of an empty history', () async {
    final api = ApiService(
      client: MockClient((_) async => throw http.ClientException('offline')),
    );
    await expectLater(api.getHistory(), throwsA(isA<ApiException>()));
  });
  test('invalid recargas never reach the network', () async {
    final api = ApiService(
      client: MockClient((_) async => throw StateError('Unexpected request')),
    );
    expect(
      (await api.recharge(amount: 0, pointName: 'point', userId: 1))['success'],
      false,
    );
    expect(
      (await api.recharge(amount: 100, pointName: 'point'))['success'],
      false,
    );
  });
}
