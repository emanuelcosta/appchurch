import '../../core/utils/formatters.dart';
import '../../core/utils/json.dart';
import '../dashboard/dashboard_models.dart';

enum LedgerKind { revenue, expense, payable }

/// Item do extrato do ciclo: receita, despesa paga ou conta a pagar.
class LedgerItem {
  const LedgerItem({
    required this.id,
    required this.kind,
    required this.date,
    required this.description,
    required this.amount,
    this.fundCode,
    this.category,
    this.paymentMethod,
    this.funds = const {},
    this.remaining,
    this.pendingSync = false,
  });

  factory LedgerItem.fromJson(Map<String, dynamic> json) => LedgerItem(
    id: asString(json['id']) ?? '',
    kind: switch (json['kind']) {
      'EXPENSE' => LedgerKind.expense,
      'PAYABLE' => LedgerKind.payable,
      _ => LedgerKind.revenue,
    },
    date: asDate(json['date']),
    description: asString(json['description']) ?? 'Sem descrição',
    amount: asDouble(json['amount']),
    fundCode: asString(json['fundCode']),
    category: asString(json['category']),
    paymentMethod: asString(json['paymentMethod']),
    funds: asMap(
      json['funds'],
    ).map((code, value) => MapEntry(code, asDouble(value))),
    remaining: json['remaining'] == null ? null : asDouble(json['remaining']),
  );

  final String id;
  final LedgerKind kind;

  /// Receita: data do lançamento; despesa: pagamento; conta: vencimento.
  final DateTime? date;
  final String description;
  final double amount;
  final String? fundCode;
  final String? category;
  final String? paymentMethod;
  final Map<String, double> funds;

  /// Conta a pagar: quanto ainda falta pagar.
  final double? remaining;

  /// Lançado offline, ainda na fila de sincronização.
  final bool pendingSync;

  bool get isIncome => kind == LedgerKind.revenue;

  /// Rótulo usado nos filtros: tipo da receita ou categoria da despesa.
  String get tag => switch (kind) {
    LedgerKind.revenue => category ?? fundNames[fundCode] ?? 'Receita',
    _ => category ?? 'Sem categoria',
  };

  String get fundsLabel =>
      funds.keys.map((code) => fundNames[code] ?? code).join(' + ');

  /// Busca do extrato: descrição, nome, tipo ou valor ("47,60", "47.6",
  /// "R$ 47" ou só parte do valor, como "47").
  bool matches(String query) {
    final text = query.trim().toLowerCase();
    if (text.isEmpty) return true;
    final values = [amount, ?remaining];
    final number = parseMoney(text);
    if (number != null &&
        values.any((value) => (value - number).abs() < 0.005)) {
      return true;
    }
    final searchable = [
      description,
      tag,
      ...values.map(formatMoney),
    ].join(' ').toLowerCase();
    return searchable.contains(text);
  }
}

class LedgerData {
  const LedgerData({
    required this.cycles,
    required this.cycle,
    required this.items,
  });

  factory LedgerData.fromJson(Map<String, dynamic> json) {
    final cycle = json['cycle'];
    return LedgerData(
      cycles: asMapList(json['cycles']).map(CycleInfo.fromJson).toList(),
      cycle: cycle is Map ? CycleInfo.fromJson(asMap(cycle)) : null,
      items: asMapList(json['items']).map(LedgerItem.fromJson).toList(),
    );
  }

  final List<CycleInfo> cycles;
  final CycleInfo? cycle;
  final List<LedgerItem> items;

  List<LedgerItem> get payables =>
      items.where((item) => item.kind == LedgerKind.payable).toList();

  LedgerData withItems(List<LedgerItem> items) =>
      LedgerData(cycles: cycles, cycle: cycle, items: items);
}
