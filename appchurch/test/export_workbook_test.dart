import 'package:appchurch/features/dashboard/dashboard_models.dart';
import 'package:appchurch/features/export/members_workbook.dart';
import 'package:appchurch/features/export/statement_workbook.dart';
import 'package:appchurch/features/ledger/ledger_models.dart';
import 'package:appchurch/features/members/member.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

/// Valores de uma aba como texto, para conferir o conteúdo: datas como
/// aaaa-mm-dd e números sem ".0" (o Excel guarda inteiros como inteiros).
List<List<String>> _rows(Excel excel, String sheet) => [
  for (final row in excel[sheet].rows)
    [for (final cell in row) _text(cell?.value)],
];

String _text(CellValue? value) => switch (value) {
  null => '',
  DateCellValue(:final year, :final month, :final day) =>
    '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}',
  DoubleCellValue(value: final number) =>
    number == number.roundToDouble()
        ? number.toInt().toString()
        : number.toString(),
  _ => value.toString(),
};

bool _hasRow(List<List<String>> rows, List<String> start) => rows.any(
  (row) =>
      row.length >= start.length &&
      List.generate(start.length, (i) => row[i] == start[i]).every((ok) => ok),
);

void main() {
  final items = [
    LedgerItem(
      id: 'r1',
      kind: LedgerKind.revenue,
      date: DateTime(2026, 9, 15),
      description: 'Culto de doutrina',
      amount: 14.75,
      fundCode: 'OFERTAS_CULTO',
      category: 'Oferta de culto',
      pixAmount: 10,
      cashAmount: 4.75,
    ),
    LedgerItem(
      id: 'r2',
      kind: LedgerKind.revenue,
      date: DateTime(2026, 9, 20),
      description: 'Ivan',
      amount: 200,
      fundCode: 'DIZIMOS',
      pixAmount: 200,
    ),
    LedgerItem(
      id: 'e1',
      kind: LedgerKind.expense,
      date: DateTime(2026, 9, 22),
      description: 'Aluguel',
      category: 'ALUGUEL',
      paymentMethod: 'PIX',
      amount: 350,
      funds: const {'DIZIMOS': 300, 'OFERTAS_CULTO': 50},
    ),
  ];

  test('extrato por ciclo: resumo da aba RELATORIO_MENSAL e abas por tipo', () {
    final report = DashboardData.fromJson({
      'cycle': {
        'id': 'c1',
        'startDate': '2026-09-14',
        'endDate': '2026-10-11',
        'status': 'OPEN',
      },
      'funds': {
        'OFERTAS_CULTO': {
          'opening': 35.27,
          'revenue': 14.75,
          'expenses': 50,
          'closing': 0.02,
        },
      },
      'transfers': [
        {'destinationName': 'Dirigente', 'amount': 40, 'status': 'PREVISTO'},
      ],
    });
    final excel = Excel.decodeBytes(
      buildStatementWorkbook(
        items: items,
        report: report,
        periodLabel: cyclePeriodLabel(report.cycle),
        congregationName: 'ADTC Eixo do Carro',
      ),
    );

    expect(
      excel.tables.keys,
      containsAll([
        'Resumo',
        'Ofertas de culto',
        'Dízimos',
        'Ofertas alçadas',
        'Despesas',
        'Contas a pagar',
      ]),
    );
    final resumo = _rows(excel, 'Resumo');
    expect(resumo.first.first, 'ADTC Eixo do Carro — Extrato');
    expect(_hasRow(resumo, ['Total de ofertas de culto', '50.02']), isTrue);
    expect(_hasRow(resumo, ['Dirigente', '40', 'Previsto']), isTrue);

    final ofertas = _rows(excel, 'Ofertas de culto');
    expect(_hasRow(ofertas, ['2026-09-15', 'Culto de doutrina']), isTrue);
    expect(_hasRow(ofertas, ['Total', '', '', '10', '4.75', '14.75']), isTrue);

    final despesas = _rows(excel, 'Despesas');
    expect(
      _hasRow(despesas, [
        '2026-09-22',
        'Aluguel',
        'ALUGUEL',
        'PIX',
        '350',
        '50',
        '300',
      ]),
      isTrue,
    );
  });

  test('extrato por período: resumo com entradas e saídas por fundo', () {
    final excel = Excel.decodeBytes(
      buildStatementWorkbook(
        items: items,
        periodLabel: '01/09/2026 a 30/09/2026',
      ),
    );
    final resumo = _rows(excel, 'Resumo');
    expect(_hasRow(resumo, ['Dízimos', '200', '300', '-100']), isTrue);
    expect(_hasRow(resumo, ['Total', '214.75', '350']), isTrue);
  });

  test('membros: ficha completa nas colunas da planilha de membros', () {
    final excel = Excel.decodeBytes(
      buildMembersWorkbook([
        Member(
          id: 'm1',
          fullName: 'Ana Souza',
          birthDate: DateTime(1990, 10, 4),
          cpf: '12345678901',
          holySpiritBaptism: true,
          childrenCount: 2,
        ),
      ]),
    );
    final rows = _rows(excel, 'Membros');
    expect(rows.any((row) => row.contains('CPF')), isTrue);
    expect(
      _hasRow(rows, ['Ana Souza', '1990-10-04', '', '', '12345678901']),
      isTrue,
    );
    final ana = rows.firstWhere((row) => row.first == 'Ana Souza');
    expect(ana, contains('Sim'));
    expect(ana, contains('2'));
  });
}
