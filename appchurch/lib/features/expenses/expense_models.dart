import '../../core/utils/json.dart';

class ExpenseCategory {
  const ExpenseCategory({required this.id, required this.name});

  factory ExpenseCategory.fromJson(Map<String, dynamic> json) =>
      ExpenseCategory(
        id: asString(json['id']) ?? '',
        name: asString(json['name']) ?? 'Sem nome',
      );

  final String id;
  final String name;
}

/// Situação do rateio: quanto já foi distribuído entre as fontes.
enum SplitStatus { empty, missing, complete, exceeded }

/// Divisão do valor de uma despesa entre as fontes de dinheiro, como na
/// planilha: informa quanto falta para completar o valor.
class FundingSplit {
  const FundingSplit({required this.total, required this.sources});

  final double total;
  final Map<String, double> sources;

  double get allocated =>
      _round(sources.values.fold(0, (sum, value) => sum + value));

  /// Positivo: falta; negativo: passou do total.
  double get remaining => _round(total - allocated);

  SplitStatus get status {
    if (total <= 0) return SplitStatus.empty;
    if (remaining.abs() < 0.01) return SplitStatus.complete;
    return remaining > 0 ? SplitStatus.missing : SplitStatus.exceeded;
  }

  /// Valor sugerido ao tocar "Usar o que falta" numa fonte: completa o
  /// total sem passar do saldo disponível dela.
  double suggestionFor(String fund, double available) {
    final current = sources[fund] ?? 0;
    final missing = remaining + current;
    if (missing <= 0) return current;
    final limit = available > 0 ? available : missing;
    return _round(missing < limit ? missing : limit);
  }

  Map<String, double> get nonZeroSources => {
    for (final entry in sources.entries)
      if (entry.value > 0) entry.key: _round(entry.value),
  };

  static double _round(double value) => (value * 100).round() / 100;
}
