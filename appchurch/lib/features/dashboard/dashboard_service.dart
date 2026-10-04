import '../../core/api/api_client.dart';
import 'dashboard_models.dart';

class DashboardService {
  const DashboardService(this._api);

  final ApiClient _api;

  /// Carrega o dashboard do ciclo informado ou, sem [cycleId], do ciclo atual.
  Future<DashboardData> load({String? cycleId}) async {
    final data = await _api.get(
      'finance/dashboard',
      query: {'congregationId': _api.congregationId, 'cycleId': ?cycleId},
    );
    if (data is! Map) {
      throw StateError(
        'A API retornou uma resposta inválida para o dashboard.',
      );
    }
    return DashboardData.fromJson(Map<String, dynamic>.from(data));
  }
}
