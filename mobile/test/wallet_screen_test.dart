import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parku_mobile/models/transaction_model.dart';
import 'package:parku_mobile/screens/wallet_screen.dart';
import 'package:parku_mobile/services/api_service.dart';
import 'package:parku_mobile/widgets/balance_card.dart';

class WalletFixture extends ApiService {
  Future<int> balance = Future.value(10000);
  List<TransactionModel> history = [];

  @override
  Future<int> getBalance() => balance;

  @override
  Future<List<TransactionModel>> getHistory() async => history;
}

void main() {
  testWidgets('shows loading without a zero balance, then empty history', (
    tester,
  ) async {
    final pending = Completer<int>();
    final api = WalletFixture()..balance = pending.future;
    await tester.pumpWidget(MaterialApp(home: WalletScreen(apiService: api)));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(BalanceCard), findsNothing);

    pending.complete(10000);
    await tester.pumpAndSettle();
    expect(tester.widget<BalanceCard>(find.byType(BalanceCard)).balance, 10000);
    expect(find.text('No hay movimientos registrados.'), findsOneWidget);
    expect(find.text('Consulta de estado no disponible.'), findsOneWidget);
  });

  testWidgets(
    'wallet failure offers a retry without hiding a recovered balance',
    (tester) async {
      final pending = Completer<int>();
      final api = WalletFixture()..balance = pending.future;
      await tester.pumpWidget(
        MaterialApp(
          home: WalletScreen(
            apiService: api,
            loadParkingStatus: () async =>
                throw const ApiException('Sin conexión'),
          ),
        ),
      );

      pending.completeError(const ApiException('El saldo no está disponible.'));
      await tester.pumpAndSettle();
      expect(find.text('El saldo no está disponible.'), findsOneWidget);
      expect(find.byType(BalanceCard), findsNothing);

      api.balance = Future.value(10000);
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<BalanceCard>(find.byType(BalanceCard)).balance,
        10000,
      );
      expect(find.text('Consulta de estado no disponible.'), findsOneWidget);
    },
  );

  testWidgets(
    'refresh reflects insufficient balance and then a confirmed debit',
    (tester) async {
      final api = WalletFixture();
      var status = ParkingStatus.insufficientBalance;
      await tester.pumpWidget(
        MaterialApp(
          home: WalletScreen(
            apiService: api,
            loadParkingStatus: () async => status,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Saldo insuficiente para completar la salida.'),
        findsOneWidget,
      );
      expect(find.text('Cobro de estacionamiento'), findsNothing);

      api.balance = Future.value(7500);
      api.history = [
        TransactionModel(
          id: 1,
          type: TransactionModel.parkingChargeType,
          amount: -2500,
          pointName: 'Portería',
          reference: 'PRUEBA-01',
          balanceAfter: 7500,
          createdAt: '',
          parkingRateLabel: '2.500 COP de prueba',
        ),
        TransactionModel(
          id: 2,
          type: TransactionModel.inPersonRechargeType,
          amount: 10000,
          pointName: 'Taquilla',
          reference: 'PRUEBA-02',
          balanceAfter: 10000,
          createdAt: '',
        ),
      ];
      status = ParkingStatus.outside;
      await tester.tap(find.byTooltip('Actualizar saldo y movimientos'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<BalanceCard>(find.byType(BalanceCard)).balance,
        7500,
      );
      expect(find.text('Sin ingreso activo.'), findsOneWidget);
      expect(find.text('Cobro de estacionamiento'), findsOneWidget);
      expect(find.text('Tarifa aplicada: 2.500 COP de prueba'), findsOneWidget);
      expect(find.text('−\$2.500 COP'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Recarga presencial'), 100);
      await tester.pumpAndSettle();
      expect(find.text('Recarga presencial'), findsOneWidget);
      expect(find.text('+\$10.000 COP'), findsOneWidget);
    },
  );
}
