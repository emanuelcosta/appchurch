import 'package:appchurch/features/dashboard/dashboard_models.dart';
import 'package:appchurch/features/dashboard/pending_adjustment.dart';
import 'package:appchurch/features/ledger/ledger_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final dashboard = DashboardData.fromJson({
    'cycle': {'id': 'c1', 'startDate': '2026-09-14', 'status': 'OPEN'},
    'funds': {
      'OFERTAS_CULTO': {
        'opening': 35.27,
        'revenue': 48.1,
        'expenses': 16,
        'closing': 67.37,
      },
      'DIZIMOS': {'opening': 0, 'revenue': 363, 'expenses': 0, 'closing': 363},
    },
    'tithe': {
      'gross': 363,
      'expenses': 0,
      'leaderPercentage': 20,
      'leaderAmount': 72.6,
      'headquartersAmount': 290.4,
      'balanceBeforeTransfers': 363,
    },
  });

  const culto = LedgerItem(
    id: 'r1',
    kind: LedgerKind.revenue,
    date: null,
    description: 'Culto',
    amount: 48.1,
    fundCode: 'OFERTAS_CULTO',
  );

  test('oferta e dízimo lançados offline entram nos saldos', () {
    final adjusted = includePending(
      dashboard,
      server: [culto],
      merged: [
        culto,
        const LedgerItem(
          id: 'r2',
          kind: LedgerKind.revenue,
          date: null,
          description: 'Culto de domingo',
          amount: 20,
          fundCode: 'OFERTAS_CULTO',
          pendingSync: true,
        ),
        const LedgerItem(
          id: 'r3',
          kind: LedgerKind.revenue,
          date: null,
          description: 'Maria',
          amount: 100,
          fundCode: 'DIZIMOS',
          pendingSync: true,
        ),
      ],
      pendingCount: 2,
    );

    expect(adjusted.pendingIncluded, 2);
    expect(adjusted.fund('OFERTAS_CULTO').revenue, closeTo(68.1, 0.001));
    expect(adjusted.fund('OFERTAS_CULTO').closing, closeTo(87.37, 0.001));
    expect(adjusted.tithe!.gross, 463);
    expect(adjusted.tithe!.balanceBeforeTransfers, 463);
    // Repasses continuam os da API até sincronizar.
    expect(adjusted.tithe!.leaderAmount, 72.6);
  });

  test('despesa paga offline sai do fundo de origem', () {
    final adjusted = includePending(
      dashboard,
      server: [culto],
      merged: [
        culto,
        const LedgerItem(
          id: 'pay',
          kind: LedgerKind.expense,
          date: null,
          description: 'Água',
          amount: 30,
          funds: {'OFERTAS_CULTO': 10, 'DIZIMOS': 20},
          pendingSync: true,
        ),
      ],
      pendingCount: 1,
    );

    expect(adjusted.fund('OFERTAS_CULTO').expenses, 26);
    expect(adjusted.fund('OFERTAS_CULTO').closing, closeTo(57.37, 0.001));
    expect(adjusted.tithe!.expenses, 20);
    expect(adjusted.tithe!.balanceBeforeTransfers, 343);
  });

  test('estorno offline tira o valor do saldo', () {
    final adjusted = includePending(
      dashboard,
      server: [culto],
      merged: const [],
      pendingCount: 1,
    );
    expect(adjusted.fund('OFERTAS_CULTO').revenue, closeTo(0, 0.001));
    expect(adjusted.fund('OFERTAS_CULTO').closing, closeTo(19.27, 0.001));
  });

  test('sem diferença, mantém os valores da API', () {
    final adjusted = includePending(
      dashboard,
      server: [culto],
      merged: [culto],
      pendingCount: 1,
    );
    expect(identical(adjusted, dashboard), isTrue);
  });
}
