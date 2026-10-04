import '../ledger/ledger_models.dart';
import 'dashboard_models.dart';

/// Soma nos saldos do ciclo aberto o que foi lançado offline e ainda não
/// sincronizou, para o Início, o relatório e o "Disponível" do rateio
/// refletirem na hora o que o tesoureiro fez.
///
/// A diferença vem do próprio extrato: [server] (como está na API) contra
/// [merged] (com a fila aplicada). Só entradas e saídas por fundo são
/// ajustadas; os repasses continuam os calculados pela API e são
/// recalculados quando a fila sincronizar. Valores provisórios.
DashboardData includePending(
  DashboardData data, {
  required List<LedgerItem> server,
  required List<LedgerItem> merged,
  required int pendingCount,
}) {
  final revenueDelta = _subtract(_revenues(merged), _revenues(server));
  final expenseDelta = _subtract(_expenses(merged), _expenses(server));
  final changed = [
    ...revenueDelta.values,
    ...expenseDelta.values,
  ].any((value) => value.abs() >= 0.005);
  if (!changed) return data;

  final funds = {
    for (final MapEntry(key: code, value: fund) in data.funds.entries)
      code: _adjust(fund, revenueDelta[code] ?? 0, expenseDelta[code] ?? 0),
  };
  final tithe = data.tithe;
  final titheRevenue = revenueDelta['DIZIMOS'] ?? 0;
  final titheExpenses = expenseDelta['DIZIMOS'] ?? 0;
  return data.withPending(
    funds: funds,
    tithe: tithe == null
        ? null
        : TitheSummary(
            gross: tithe.gross + titheRevenue,
            expenses: tithe.expenses + titheExpenses,
            leaderPercentage: tithe.leaderPercentage,
            leaderAmount: tithe.leaderAmount,
            headquartersAmount: tithe.headquartersAmount,
            balanceBeforeTransfers:
                tithe.balanceBeforeTransfers + titheRevenue - titheExpenses,
            headquartersNegative: tithe.headquartersNegative,
          ),
    pendingIncluded: pendingCount,
  );
}

FundBalance _adjust(FundBalance fund, double revenue, double expenses) =>
    FundBalance(
      opening: fund.opening,
      revenue: fund.revenue + revenue,
      expenses: fund.expenses + expenses,
      closing: fund.closing + revenue - expenses,
    );

/// Entradas por fundo (receitas do extrato).
Map<String, double> _revenues(List<LedgerItem> items) {
  final totals = <String, double>{};
  for (final item in items) {
    if (item.kind != LedgerKind.revenue || item.fundCode == null) continue;
    totals[item.fundCode!] = (totals[item.fundCode!] ?? 0) + item.amount;
  }
  return totals;
}

/// Saídas por fundo (rateio das despesas pagas).
Map<String, double> _expenses(List<LedgerItem> items) {
  final totals = <String, double>{};
  for (final item in items) {
    if (item.kind != LedgerKind.expense) continue;
    for (final MapEntry(key: fund, value: amount) in item.funds.entries) {
      totals[fund] = (totals[fund] ?? 0) + amount;
    }
  }
  return totals;
}

Map<String, double> _subtract(Map<String, double> a, Map<String, double> b) => {
  for (final fund in {...a.keys, ...b.keys})
    fund: (a[fund] ?? 0) - (b[fund] ?? 0),
};
