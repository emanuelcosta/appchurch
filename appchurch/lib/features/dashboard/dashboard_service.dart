import '../../core/api/api_client.dart';
import '../ledger/ledger_service.dart';
import 'dashboard_models.dart';
import 'pending_adjustment.dart';

class DashboardService {
  const DashboardService(this._api);

  final ApiClient _api;

  /// Carrega o dashboard do ciclo informado ou, sem [cycleId], do ciclo atual.
  /// No ciclo aberto, soma o que foi lançado offline e ainda não sincronizou
  /// (valores provisórios; ver [DashboardData.pendingIncluded]).
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
    final dashboard = DashboardData.fromJson(Map<String, dynamic>.from(data));
    return _withPending(dashboard);
  }

  Future<DashboardData> _withPending(DashboardData dashboard) async {
    final cycle = dashboard.cycle;
    if (cycle == null || !cycle.isOpen) return dashboard;
    final pendingCount = await _api.pendingWrites();
    if (pendingCount == 0) return dashboard;
    try {
      final ledger = await LedgerService(
        _api,
      ).loadWithPending(cycleId: cycle.id);
      return includePending(
        dashboard,
        server: ledger.server.items,
        merged: ledger.merged.items,
        pendingCount: pendingCount,
      );
    } catch (_) {
      // Sem o extrato salvo: mostra os valores da API, sem os pendentes.
      return dashboard;
    }
  }
}
