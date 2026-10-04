import '../../core/api/api_client.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/json.dart';
import '../dashboard/dashboard_models.dart';

/// Fechamento e abertura de ciclos de prestação de contas.
/// Exige conexão: o fechamento grava a prestação de contas oficial.
class CyclesService {
  const CyclesService(this._api);

  final ApiClient _api;

  /// Prévia do fechamento com a data final informada (calculada pela API).
  Future<DashboardData> preview(String cycleId, DateTime endDate) async {
    final data = await _api.get(
      'finance/closures/$cycleId/preview',
      query: {'endDate': toIsoDate(endDate)},
    );
    if (data is! Map) {
      throw StateError('A API retornou uma resposta inválida para a prévia.');
    }
    return DashboardData.fromJson(asMap(data));
  }

  /// Fecha o ciclo e retorna o novo ciclo aberto pela API.
  Future<CycleInfo> close(
    String cycleId,
    DateTime endDate, {
    String? notes,
  }) async {
    final data = await _api.post(
      'finance/closures/$cycleId/close',
      data: {'periodEnd': toIsoDate(endDate), 'notes': ?notes},
    );
    return CycleInfo.fromJson(asMap(asMap(data)['nextCycle']));
  }

  Future<void> open(DateTime startDate) async {
    await _api.post(
      'finance/closures',
      data: {
        'congregationId': _api.congregationId,
        'periodStart': toIsoDate(startDate),
      },
    );
  }
}
