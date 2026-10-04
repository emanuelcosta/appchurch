import 'package:appchurch/features/ledger/ledger_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const cagece = LedgerItem(
    id: 'e1',
    kind: LedgerKind.expense,
    date: null,
    description: 'Conta de água',
    category: 'CAGECE',
    amount: 47.6,
  );
  const aluguel = LedgerItem(
    id: 'e2',
    kind: LedgerKind.expense,
    date: null,
    description: 'Aluguel',
    amount: 1234.56,
  );

  test('busca por descrição e categoria, sem diferenciar maiúsculas', () {
    expect(cagece.matches('cagece'), isTrue);
    expect(cagece.matches('ÁGUA'.toLowerCase()), isTrue);
    expect(cagece.matches('luz'), isFalse);
    expect(cagece.matches(''), isTrue);
  });

  test('busca por valor em vários formatos', () {
    for (final query in ['47,60', '47.60', '47,6', 'R\$ 47,60', '47']) {
      expect(cagece.matches(query), isTrue, reason: query);
    }
    expect(cagece.matches('47,61'), isFalse);
    expect(aluguel.matches('1.234,56'), isTrue);
    expect(aluguel.matches('1234,56'), isTrue);
    expect(aluguel.matches('47,60'), isFalse);
  });
}
