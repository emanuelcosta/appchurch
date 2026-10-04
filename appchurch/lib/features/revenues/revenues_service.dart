import '../../core/api/api_client.dart';
import '../../core/utils/json.dart';

/// Tipo principal de cada fundo, sugerido ao abrir o lançamento.
const defaultRevenueCategoryCodes = {'OFERTA_CULTO', 'OFERTA_ALCADA', 'DIZIMO'};

class RevenueCategory {
  const RevenueCategory({
    required this.id,
    required this.name,
    required this.fundCode,
    this.code,
  });

  factory RevenueCategory.fromJson(Map<String, dynamic> json) =>
      RevenueCategory(
        id: asString(json['id']) ?? '',
        code: asString(json['code']),
        name: asString(json['name']) ?? 'Sem nome',
        fundCode: asString(json['fundCode']) ?? '',
      );

  final String id;
  final String? code;
  final String name;
  final String fundCode;

  bool get isDefault => defaultRevenueCategoryCodes.contains(code);
}

class RevenuesService {
  const RevenuesService(this._api);

  final ApiClient _api;

  /// Tipos de receita cadastrados (funciona offline com a última cópia).
  Future<List<RevenueCategory>> categories() async {
    final data = await _api.get(
      'finance/revenue-categories',
      query: {'congregationId': _api.congregationId},
    );
    return asMapList(data).map(RevenueCategory.fromJson).toList();
  }

  /// Envia a receita ou, sem conexão, guarda na fila para sincronizar.
  Future<SendResult> create(Map<String, Object?> body) => _api.send(
    'finance/revenues',
    {...body, 'congregationId': _api.congregationId},
  );
}
