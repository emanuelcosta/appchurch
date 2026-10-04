import 'package:appchurch/features/ledger/ledger_models.dart';
import 'package:appchurch/features/ledger/pending_overlay.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final culto = LedgerItem(
    id: 'r1',
    kind: LedgerKind.revenue,
    date: DateTime(2026, 9, 15),
    description: 'Culto de doutrina',
    amount: 14.75,
    pixAmount: 10,
    cashAmount: 4.75,
  );
  final cagece = LedgerItem(
    id: 'p1',
    kind: LedgerKind.payable,
    date: DateTime(2026, 10, 5),
    description: 'CAGECE',
    category: 'CAGECE',
    amount: 50.73,
    remaining: 50.73,
  );
  final aluguel = LedgerItem(
    id: 'pay-1',
    kind: LedgerKind.expense,
    date: DateTime(2026, 9, 20),
    description: 'Aluguel',
    amount: 350,
    payableId: 'payable-1',
    paidOnCreation: true,
  );

  test('receita nova offline entra no extrato como pendente', () {
    final items = applyPendingOperations(
      [culto],
      [
        (
          path: 'finance/revenues',
          body: {
            'id': 'r2',
            'fundCode': 'DIZIMOS',
            'date': '2026-10-04',
            'description': 'Maria',
            'pixAmount': 100,
            'cashAmount': 0,
          },
        ),
      ],
    );
    expect(items, hasLength(2));
    final maria = items.firstWhere((item) => item.id == 'r2');
    expect(maria.amount, 100);
    expect(maria.pendingSync, isTrue);
  });

  test('edição offline substitui os valores e marca como pendente', () {
    final items = applyPendingOperations(
      [culto],
      [
        (
          path: 'finance/revenues',
          body: {
            'id': 'r1',
            'fundCode': 'OFERTAS_CULTO',
            'date': '2026-09-15',
            'description': 'Culto de doutrina',
            'pixAmount': 10,
            'cashAmount': 9.75,
          },
        ),
      ],
    );
    expect(items.single.amount, 19.75);
    expect(items.single.pendingSync, isTrue);
  });

  test('pagamento parcial reduz o valor em aberto e aparece como saída', () {
    final items = applyPendingOperations(
      [cagece],
      [
        (
          path: 'finance/payables/p1/pay',
          body: {
            'paymentId': 'pp1',
            'paymentDate': '2026-10-04',
            'amount': 20,
            'fundingSources': {'OFERTAS_CULTO': 20},
          },
        ),
      ],
    );
    final payable = items.firstWhere((item) => item.id == 'p1');
    expect(payable.remaining, closeTo(30.73, 0.001));
    final payment = items.firstWhere((item) => item.id == 'pp1');
    expect(payment.kind, LedgerKind.expense);
    expect(payment.description, 'CAGECE');
    expect(payment.pendingSync, isTrue);
  });

  test('pagamento total tira a conta da lista de "a pagar"', () {
    final items = applyPendingOperations(
      [cagece],
      [
        (
          path: 'finance/payables/p1/pay',
          body: {'paymentId': 'pp1', 'amount': 50.73},
        ),
      ],
    );
    expect(items.where((item) => item.kind == LedgerKind.payable), isEmpty);
  });

  test('estorno offline tira a receita do extrato', () {
    final items = applyPendingOperations(
      [culto],
      [
        (path: 'finance/revenues/r1/reverse', body: {'reason': 'duplicada'}),
      ],
    );
    expect(items, isEmpty);
  });

  test('estorno mantendo a conta em aberto devolve a conta a pagar', () {
    final items = applyPendingOperations(
      [aluguel],
      [
        (
          path: 'finance/payments/pay-1/reverse',
          body: {'reason': 'não pago', 'cancelExpense': false},
        ),
      ],
    );
    final payable = items.single;
    expect(payable.kind, LedgerKind.payable);
    expect(payable.id, 'payable-1');
    expect(payable.remaining, 350);
  });

  test('cancelar conta offline tira a conta do extrato', () {
    final items = applyPendingOperations(
      [cagece],
      [
        (path: 'finance/payables/p1/cancel', body: {'reason': 'errada'}),
      ],
    );
    expect(items, isEmpty);
  });
}
