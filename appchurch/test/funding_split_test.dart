import 'package:appchurch/core/utils/formatters.dart';
import 'package:appchurch/features/expenses/expense_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lê valores no padrão brasileiro', () {
    expect(parseMoney('1.234,56'), 1234.56);
    expect(parseMoney('12,5'), 12.5);
    expect(parseMoney('12.5'), 12.5);
    expect(parseMoney('R\$ 300'), 300);
    expect(parseMoney(''), isNull);
  });

  test('mostra quanto falta e quando passa do total', () {
    const missing = FundingSplit(total: 300, sources: {'DIZIMOS': 100});
    expect(missing.status, SplitStatus.missing);
    expect(missing.remaining, 200);

    const exceeded = FundingSplit(
      total: 300,
      sources: {'DIZIMOS': 250, 'OFERTAS_CULTO': 60},
    );
    expect(exceeded.status, SplitStatus.exceeded);
    expect(exceeded.remaining, -10);

    const complete = FundingSplit(
      total: 0.3,
      sources: {'DIZIMOS': 0.1, 'OFERTAS_CULTO': 0.2},
    );
    expect(complete.status, SplitStatus.complete);
  });

  test('"usar o que falta" respeita o saldo disponível da fonte', () {
    const split = FundingSplit(total: 300, sources: {'OFERTAS_CULTO': 0});
    expect(split.suggestionFor('OFERTAS_CULTO', 67.37), 67.37);
    expect(split.suggestionFor('DIZIMOS', 363), 300);

    const partial = FundingSplit(
      total: 300,
      sources: {'OFERTAS_CULTO': 67.37, 'DIZIMOS': 0},
    );
    expect(partial.suggestionFor('DIZIMOS', 363), 232.63);
  });
}
