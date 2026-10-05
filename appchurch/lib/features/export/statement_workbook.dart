import '../../core/utils/formatters.dart';
import '../dashboard/dashboard_models.dart';
import '../ledger/ledger_models.dart';
import 'sheet_writer.dart';

/// Planilha do extrato, no formato da planilha da tesouraria: uma aba de
/// Resumo e uma aba por tipo de lançamento.
///
/// - Por ciclo ([report] informado): o resumo segue a aba RELATORIO_MENSAL
///   (saldo anterior, entradas, despesas, saldos e repasses, da API).
/// - Por período (sem [report]): o resumo traz os totais de entradas e
///   saídas por fundo dos lançamentos listados (saldo anterior e repasses
///   só existem por ciclo).
List<int> buildStatementWorkbook({
  required List<LedgerItem> items,
  required String periodLabel,
  DashboardData? report,
  String? congregationName,
}) {
  final excel = newWorkbook('Resumo');
  final pending = items.where((item) => item.pendingSync).length;
  final title = '${congregationName ?? 'Tesouraria'} — Extrato';
  if (report != null) {
    _summary(
      SheetWriter(excel, 'Resumo'),
      report,
      title: title,
      period: periodLabel,
      pending: pending,
    );
  } else {
    _periodSummary(
      SheetWriter(excel, 'Resumo'),
      items,
      title: title,
      period: periodLabel,
      pending: pending,
    );
  }

  final revenues = items.where((item) => item.kind == LedgerKind.revenue);
  _revenueSheet(
    SheetWriter(excel, 'Ofertas de culto'),
    revenues.where((item) => item.fundCode == 'OFERTAS_CULTO'),
    nameLabel: 'Descrição',
  );
  _revenueSheet(
    SheetWriter(excel, 'Dízimos'),
    revenues.where((item) => item.fundCode == 'DIZIMOS'),
    nameLabel: 'Nome',
  );
  _revenueSheet(
    SheetWriter(excel, 'Ofertas alçadas'),
    revenues.where((item) => item.fundCode == 'OFERTAS_ALCADAS'),
    nameLabel: 'Nome',
  );
  _expenseSheet(
    SheetWriter(excel, 'Despesas'),
    items.where((item) => item.kind == LedgerKind.expense),
  );
  _payableSheet(
    SheetWriter(excel, 'Contas a pagar'),
    items.where((item) => item.kind == LedgerKind.payable),
  );
  return excel.encode()!;
}

/// Texto do período de um ciclo para o cabeçalho da planilha.
String cyclePeriodLabel(CycleInfo? cycle) => cycle == null
    ? 'Sem ciclo'
    : '${formatDate(cycle.startDate)} a ${formatDate(cycle.endDate)}'
          '${cycle.isOpen ? ' (ciclo aberto)' : ' (ciclo fechado)'}';

void _periodSummary(
  SheetWriter sheet,
  List<LedgerItem> items, {
  required String title,
  required String period,
  required int pending,
}) {
  sheet
    ..title(title)
    ..note('Período: $period')
    ..note('Gerado em ${formatDate(DateTime.now())}')
    ..note(
      'Totais dos lançamentos do período. Saldo anterior e repasses '
      'constam no extrato por ciclo.',
    );
  if (pending > 0) {
    sheet.note('Inclui lançamentos ainda não sincronizados com a API.');
  }
  double revenue(String fund) => items
      .where((item) => item.kind == LedgerKind.revenue && item.fundCode == fund)
      .fold(0, (total, item) => total + item.amount);
  double expense(String fund) => items
      .where((item) => item.kind == LedgerKind.expense)
      .fold(0, (total, item) => total + (item.funds[fund] ?? 0));
  sheet
    ..blank()
    ..header(['Fundo', 'Entradas', 'Saídas', 'Entradas − saídas']);
  for (final MapEntry(key: code, value: name) in fundNames.entries) {
    sheet.row([
      XText(name),
      XMoney(revenue(code)),
      XMoney(expense(code)),
      XMoney(revenue(code) - expense(code)),
    ]);
  }
  final totalIn = fundNames.keys.fold(0.0, (t, code) => t + revenue(code));
  final totalOut = fundNames.keys.fold(0.0, (t, code) => t + expense(code));
  sheet
    ..row([
      const XText('Total'),
      XMoney(totalIn),
      XMoney(totalOut),
      XMoney(totalIn - totalOut),
    ], bold: true)
    ..finish();
}

String _situation(LedgerItem item) =>
    item.pendingSync ? 'Aguardando sincronização' : 'Sincronizado';

int _byDate(LedgerItem a, LedgerItem b) =>
    (a.date ?? DateTime(1900)).compareTo(b.date ?? DateTime(1900));

void _summary(
  SheetWriter sheet,
  DashboardData report, {
  required String title,
  required String period,
  required int pending,
}) {
  final culto = report.fund('OFERTAS_CULTO');
  final alcadas = report.fund('OFERTAS_ALCADAS');
  final dizimos = report.fund('DIZIMOS');
  final tithe = report.tithe;
  sheet
    ..title(title)
    ..note('Período: $period')
    ..note('Gerado em ${formatDate(DateTime.now())}');
  if (pending > 0 || report.pendingIncluded > 0) {
    sheet.note(
      'Inclui lançamentos ainda não sincronizados com a API: valores '
      'provisórios.',
    );
  }
  sheet
    ..blank()
    ..header(['Entradas', 'Valor'])
    ..labelValue('Saldo anterior — ofertas de culto', culto.opening)
    ..labelValue('Ofertas de culto', culto.revenue)
    ..labelValue(
      'Total de ofertas de culto',
      culto.opening + culto.revenue,
      bold: true,
    )
    ..labelValue('Saldo anterior — ofertas alçadas', alcadas.opening);
  for (final type in report.categoriesOf('OFERTAS_ALCADAS')) {
    sheet.labelValue('Ofertas alçadas — ${type.category}', type.amount);
  }
  if (report.categoriesOf('OFERTAS_ALCADAS').isEmpty) {
    sheet.labelValue('Ofertas alçadas', alcadas.revenue);
  }
  sheet
    ..labelValue(
      'Total de ofertas alçadas',
      alcadas.opening + alcadas.revenue,
      bold: true,
    )
    ..labelValue('Total de dízimos', dizimos.revenue, bold: true)
    ..blank()
    ..header(['Despesas', 'Valor'])
    ..labelValue('Saídas ofertas de cultos', culto.expenses)
    ..labelValue('Saídas ofertas alçadas', alcadas.expenses)
    ..labelValue('Saídas dízimos', dizimos.expenses)
    ..labelValue(
      'Total de despesas',
      culto.expenses + alcadas.expenses + dizimos.expenses,
      bold: true,
    )
    ..blank()
    ..header(['Saldos', 'Valor'])
    ..labelValue('Ofertas de culto', culto.closing)
    ..labelValue('Ofertas alçadas', alcadas.closing)
    ..labelValue(
      'Dízimos (antes dos repasses)',
      tithe?.balanceBeforeTransfers ?? dizimos.closing,
    )
    ..blank()
    ..header(['Repasses', 'Valor', 'Situação']);
  for (final transfer in report.transfers) {
    sheet.row([
      XText(transfer.destinationName),
      XMoney(transfer.amount),
      XText(transfer.statusLabel),
    ]);
  }
  sheet
    ..labelValue(
      'Total de repasses',
      report.transfers.fold(0, (total, item) => total + item.amount),
      bold: true,
    )
    ..finish();
}

void _revenueSheet(
  SheetWriter sheet,
  Iterable<LedgerItem> items, {
  required String nameLabel,
}) {
  final rows = items.toList()..sort(_byDate);
  sheet.header([
    'Data',
    nameLabel,
    'Tipo',
    'PIX',
    'Dinheiro',
    'Total',
    'Situação',
  ]);
  for (final item in rows) {
    sheet.row([
      XDate(item.date),
      XText(item.description),
      XText(item.category),
      XMoney(item.pixAmount),
      XMoney(item.cashAmount),
      XMoney(item.amount),
      XText(_situation(item)),
    ]);
  }
  sheet
    ..row([
      const XText('Total'),
      const XText(null),
      const XText(null),
      XMoney(rows.fold(0, (total, item) => total + item.pixAmount)),
      XMoney(rows.fold(0, (total, item) => total + item.cashAmount)),
      XMoney(rows.fold(0, (total, item) => total + item.amount)),
    ], bold: true)
    ..finish();
}

void _expenseSheet(SheetWriter sheet, Iterable<LedgerItem> items) {
  final rows = items.toList()..sort(_byDate);
  double fund(LedgerItem item, String code) => item.funds[code] ?? 0;
  sheet.header([
    'Data do pagamento',
    'Descrição',
    'Categoria',
    'Forma',
    'Valor pago',
    'Pago com ofertas de culto',
    'Pago com dízimos',
    'Pago com ofertas alçadas',
    'Situação',
  ]);
  for (final item in rows) {
    sheet.row([
      XDate(item.date),
      XText(item.description),
      XText(item.category),
      XText(switch (item.paymentMethod) {
        'PIX' => 'PIX',
        'CASH' => 'Dinheiro',
        final other => other,
      }),
      XMoney(item.amount),
      XMoney(fund(item, 'OFERTAS_CULTO')),
      XMoney(fund(item, 'DIZIMOS')),
      XMoney(fund(item, 'OFERTAS_ALCADAS')),
      XText(_situation(item)),
    ]);
  }
  double sum(double Function(LedgerItem item) pick) =>
      rows.fold(0, (total, item) => total + pick(item));
  sheet
    ..row([
      const XText('Total'),
      const XText(null),
      const XText(null),
      const XText(null),
      XMoney(sum((item) => item.amount)),
      XMoney(sum((item) => fund(item, 'OFERTAS_CULTO'))),
      XMoney(sum((item) => fund(item, 'DIZIMOS'))),
      XMoney(sum((item) => fund(item, 'OFERTAS_ALCADAS'))),
    ], bold: true)
    ..finish();
}

void _payableSheet(SheetWriter sheet, Iterable<LedgerItem> items) {
  final rows = items.toList()..sort(_byDate);
  sheet.header([
    'Vencimento',
    'Descrição',
    'Categoria',
    'Valor da conta',
    'Em aberto',
    'Situação',
  ]);
  for (final item in rows) {
    sheet.row([
      XDate(item.date),
      XText(item.description),
      XText(item.category),
      XMoney(item.amount),
      XMoney(item.remaining ?? item.amount),
      XText(_situation(item)),
    ]);
  }
  sheet
    ..row([
      const XText('Total'),
      const XText(null),
      const XText(null),
      XMoney(rows.fold(0, (total, item) => total + item.amount)),
      XMoney(
        rows.fold(0, (total, item) => total + (item.remaining ?? item.amount)),
      ),
    ], bold: true)
    ..finish();
}
