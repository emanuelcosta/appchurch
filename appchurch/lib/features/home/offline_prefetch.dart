import '../../core/api/api_client.dart';
import '../dashboard/dashboard_service.dart';
import '../expenses/expenses_service.dart';
import '../ledger/ledger_service.dart';
import '../members/members_service.dart';
import '../profile/profile_service.dart';
import '../revenues/revenues_service.dart';

/// Com conexão, baixa os dados de todas as telas para o cache do aparelho:
/// assim o app funciona offline mesmo em telas que ainda não foram abertas.
/// Usa os próprios serviços das telas, para o cache ficar com as mesmas
/// consultas que elas fazem.
class OfflinePrefetch {
  OfflinePrefetch(
    this._api, {
    this.interval = const Duration(minutes: 10),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final ApiClient _api;
  final Duration interval;
  final DateTime Function() _clock;
  DateTime? _lastRun;
  bool _running = false;

  void start() {
    _api.reachable.addListener(_onReachable);
    run();
  }

  void dispose() => _api.reachable.removeListener(_onReachable);

  void _onReachable() => run();

  /// Baixa tudo, no máximo uma vez a cada [interval] (ou sempre com [force]).
  Future<void> run({bool force = false}) async {
    final now = _clock();
    if (_running) return;
    if (!force && _lastRun != null && now.difference(_lastRun!) < interval) {
      return;
    }
    _running = true;
    _lastRun = now;
    try {
      final dashboard = DashboardService(_api);
      final ledger = LedgerService(_api);
      final current = await dashboard.load();
      await Future.wait(
        [
          ledger.load(),
          ledger.closedPeriods(),
          RevenuesService(_api).categories(),
          ExpensesService(_api).categories(),
          MembersService(_api).list(),
          ProfileService(_api).load(),
          // Relatório e extrato de cada ciclo (consulta de ciclos anteriores).
          for (final cycle in current.cycles) ...[
            dashboard.load(cycleId: cycle.id),
            ledger.load(cycleId: cycle.id),
          ],
        ].map(_ignoreErrors),
      );
    } catch (_) {
      // Sem conexão: tenta de novo quando a API voltar a responder.
      _lastRun = null;
    } finally {
      _running = false;
    }
  }

  static Future<void> _ignoreErrors(Future<Object?> future) =>
      future.then((_) {}, onError: (_) {});
}
