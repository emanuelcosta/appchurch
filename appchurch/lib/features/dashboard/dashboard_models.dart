import '../../core/utils/formatters.dart';
import '../../core/utils/json.dart';

/// Nomes dos fundos na mesma ordem do dashboard da planilha.
const fundNames = {
  'OFERTAS_CULTO': 'Ofertas de culto',
  'OFERTAS_ALCADAS': 'Ofertas alçadas',
  'DIZIMOS': 'Dízimos',
};

class CycleInfo {
  const CycleInfo({
    required this.id,
    required this.startDate,
    required this.endDate,
    required this.status,
  });

  factory CycleInfo.fromJson(Map<String, dynamic> json) => CycleInfo(
    id: asString(json['id']) ?? '',
    startDate: asDate(json['startDate']),
    endDate: asDate(json['endDate']),
    status: asString(json['status']) ?? '',
  );

  final String id;
  final DateTime? startDate;
  final DateTime? endDate;
  final String status;

  bool get isOpen => status == 'OPEN';

  String get label {
    final period = '${formatDate(startDate)} a ${formatDate(endDate)}';
    return isOpen ? '$period (atual)' : period;
  }
}

class FundBalance {
  const FundBalance({
    required this.opening,
    required this.revenue,
    required this.expenses,
    required this.closing,
  });

  factory FundBalance.fromJson(Map<String, dynamic> json) => FundBalance(
    opening: asDouble(json['opening']),
    revenue: asDouble(json['revenue']),
    expenses: asDouble(json['expenses']),
    closing: asDouble(json['closing']),
  );

  static const empty = FundBalance(
    opening: 0,
    revenue: 0,
    expenses: 0,
    closing: 0,
  );

  final double opening;
  final double revenue;
  final double expenses;
  final double closing;
}

class TitheSummary {
  const TitheSummary({
    required this.gross,
    required this.expenses,
    required this.leaderPercentage,
    required this.leaderAmount,
    required this.headquartersAmount,
    required this.balanceBeforeTransfers,
    required this.headquartersNegative,
  });

  factory TitheSummary.fromJson(Map<String, dynamic> json) => TitheSummary(
    gross: asDouble(json['gross']),
    expenses: asDouble(json['expenses']),
    leaderPercentage: asDouble(json['leaderPercentage']),
    leaderAmount: asDouble(json['leaderAmount']),
    headquartersAmount: asDouble(json['headquartersAmount']),
    balanceBeforeTransfers: asDouble(json['balanceBeforeTransfers']),
    headquartersNegative: asBool(json['headquartersNegative']),
  );

  final double gross;
  final double expenses;
  final double leaderPercentage;
  final double leaderAmount;
  final double headquartersAmount;
  final double balanceBeforeTransfers;
  final bool headquartersNegative;
}

class TransferInfo {
  const TransferInfo({
    required this.destinationName,
    required this.amount,
    required this.status,
  });

  factory TransferInfo.fromJson(Map<String, dynamic> json) => TransferInfo(
    destinationName: asString(json['destinationName']) ?? 'Destino',
    amount: asDouble(json['amount']),
    status: asString(json['status']) ?? '',
  );

  final String destinationName;
  final double amount;
  final String status;

  String get statusLabel => switch (status) {
    'PAGO' => 'Pago',
    'A_PAGAR' => 'A pagar',
    _ => 'Previsto',
  };
}

class CategoryRevenue {
  const CategoryRevenue({
    required this.fundCode,
    required this.category,
    required this.amount,
  });

  factory CategoryRevenue.fromJson(Map<String, dynamic> json) =>
      CategoryRevenue(
        fundCode: asString(json['fundCode']) ?? '',
        category: asString(json['category']) ?? 'Sem tipo',
        amount: asDouble(json['amount']),
      );

  final String fundCode;
  final String category;
  final double amount;
}

class TitheEntry {
  const TitheEntry({
    required this.name,
    required this.date,
    required this.amount,
  });

  factory TitheEntry.fromJson(Map<String, dynamic> json) => TitheEntry(
    name: asString(json['name']) ?? 'Sem nome',
    date: asDate(json['date']),
    amount: asDouble(json['amount']),
  );

  final String name;
  final DateTime? date;
  final double amount;
}

class PendingPayable {
  const PendingPayable({
    required this.description,
    required this.dueDate,
    required this.remaining,
    required this.overdue,
  });

  factory PendingPayable.fromJson(Map<String, dynamic> json) => PendingPayable(
    description: asString(json['description']) ?? 'Conta sem descrição',
    dueDate: asDate(json['dueDate']),
    remaining: asDouble(json['remaining']),
    overdue: asBool(json['overdue']),
  );

  final String description;
  final DateTime? dueDate;
  final double remaining;
  final bool overdue;
}

class DashboardData {
  const DashboardData({
    required this.cycles,
    required this.cycle,
    required this.funds,
    required this.tithe,
    required this.transfers,
    required this.revenueByCategory,
    required this.titheEntries,
    required this.pendingPayables,
    this.pendingIncluded = 0,
  });

  /// Cópia com saldos ajustados pelos lançamentos ainda não sincronizados.
  DashboardData withPending({
    required Map<String, FundBalance> funds,
    required TitheSummary? tithe,
    required int pendingIncluded,
  }) => DashboardData(
    cycles: cycles,
    cycle: cycle,
    funds: funds,
    tithe: tithe,
    transfers: transfers,
    revenueByCategory: revenueByCategory,
    titheEntries: titheEntries,
    pendingPayables: pendingPayables,
    pendingIncluded: pendingIncluded,
  );

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    final cycle = json['cycle'];
    final funds = asMap(json['funds']);
    final tithe = json['tithe'];
    return DashboardData(
      cycles: asMapList(json['cycles']).map(CycleInfo.fromJson).toList(),
      cycle: cycle is Map ? CycleInfo.fromJson(asMap(cycle)) : null,
      funds: {
        for (final code in fundNames.keys)
          code: funds[code] is Map
              ? FundBalance.fromJson(asMap(funds[code]))
              : FundBalance.empty,
      },
      tithe: tithe is Map ? TitheSummary.fromJson(asMap(tithe)) : null,
      transfers: asMapList(
        json['transfers'],
      ).map(TransferInfo.fromJson).toList(),
      revenueByCategory: asMapList(
        json['revenueByCategory'],
      ).map(CategoryRevenue.fromJson).toList(),
      titheEntries: asMapList(
        json['titheEntries'],
      ).map(TitheEntry.fromJson).toList(),
      pendingPayables: asMapList(
        json['pendingPayables'],
      ).map(PendingPayable.fromJson).toList(),
    );
  }

  final List<CycleInfo> cycles;
  final CycleInfo? cycle;
  final Map<String, FundBalance> funds;
  final TitheSummary? tithe;
  final List<TransferInfo> transfers;
  final List<CategoryRevenue> revenueByCategory;
  final List<TitheEntry> titheEntries;
  final List<PendingPayable> pendingPayables;

  /// Quantos lançamentos offline (ainda na fila) já estão somados nos
  /// saldos: valores provisórios até a API confirmar.
  final int pendingIncluded;

  FundBalance fund(String code) => funds[code] ?? FundBalance.empty;

  List<CategoryRevenue> categoriesOf(String fundCode) =>
      revenueByCategory.where((item) => item.fundCode == fundCode).toList();
}
