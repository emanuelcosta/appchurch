import '../../core/api/api_client.dart';
import '../../core/utils/json.dart';
import '../dashboard/dashboard_service.dart';
import 'expense_models.dart';

class ExpensesService {
  const ExpensesService(this._api);

  final ApiClient _api;

  Future<List<ExpenseCategory>> categories() async {
    final data = await _api.get(
      'finance/expense-categories',
      query: {'congregationId': _api.congregationId},
    );
    return asMapList(data).map(ExpenseCategory.fromJson).toList();
  }

  /// Saldo disponível de cada fonte no ciclo atual (calculado pela API).
  Future<Map<String, double>> availableBalances() async {
    final dashboard = await DashboardService(_api).load();
    return {
      'OFERTAS_CULTO': dashboard.fund('OFERTAS_CULTO').closing,
      'OFERTAS_ALCADAS': dashboard.fund('OFERTAS_ALCADAS').closing,
      'DIZIMOS':
          dashboard.tithe?.balanceBeforeTransfers ??
          dashboard.fund('DIZIMOS').closing,
    };
  }

  /// Envia a despesa ou, sem conexão, guarda na fila para sincronizar.
  Future<SendResult> create(Map<String, Object?> body) => _api.send(
    'finance/expenses',
    {...body, 'congregationId': _api.congregationId},
  );
}
