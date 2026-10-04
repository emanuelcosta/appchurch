import '../../core/api/api_client.dart';
import '../../core/utils/json.dart';
import 'ledger_models.dart';

/// Extrato do ciclo (receitas, despesas e contas a pagar) e pagamento de
/// contas. Lançamentos feitos offline aparecem como "aguardando
/// sincronização" até a fila ser enviada.
class LedgerService {
  const LedgerService(this._api);

  final ApiClient _api;

  Future<LedgerData> load({String? cycleId}) async {
    final data = await _api.get(
      'finance/ledger',
      query: {'congregationId': _api.congregationId, 'cycleId': ?cycleId},
    );
    if (data is! Map) {
      throw StateError('A API retornou uma resposta inválida para o extrato.');
    }
    final ledger = LedgerData.fromJson(Map<String, dynamic>.from(data));
    final pending = await _pendingItems();
    final known = ledger.items.map((item) => item.id).toSet();
    return ledger.withItems([
      ...pending.where((item) => !known.contains(item.id)),
      ...ledger.items,
    ]);
  }

  /// Paga (total ou parcialmente) uma conta; sem conexão, vai para a fila.
  Future<SendResult> pay(String payableId, Map<String, Object?> body) =>
      _api.send('finance/payables/$payableId/pay', {
        ...body,
        'congregationId': _api.congregationId,
      });

  /// Receitas e despesas lançadas offline que ainda não foram enviadas.
  Future<List<LedgerItem>> _pendingItems() async {
    final database = _api.database;
    if (database == null) return [];
    final operations = await database.pendingOperations(_api.congregationId);
    final items = <LedgerItem>[];
    for (final operation in operations) {
      if (operation.entityType != apiRequestEntity) continue;
      final body = asMap(operation.payload['body']);
      switch (operation.payload['path']) {
        case 'finance/revenues':
          items.add(
            LedgerItem(
              id: asString(body['id']) ?? operation.id,
              kind: LedgerKind.revenue,
              date: asDate(body['date']),
              description: asString(body['description']) ?? 'Receita',
              amount:
                  asDouble(body['pixAmount']) + asDouble(body['cashAmount']),
              fundCode: asString(body['fundCode']),
              pendingSync: true,
            ),
          );
        case 'finance/expenses':
          items.add(
            LedgerItem(
              id: asString(body['id']) ?? operation.id,
              kind: body['status'] == 'PAYABLE'
                  ? LedgerKind.payable
                  : LedgerKind.expense,
              date: asDate(body['paymentDate'] ?? body['dueDate']),
              description: asString(body['description']) ?? 'Despesa',
              amount: asDouble(body['amount']),
              remaining: body['status'] == 'PAYABLE'
                  ? asDouble(body['amount'])
                  : null,
              funds: asMap(
                body['fundingSources'],
              ).map((code, value) => MapEntry(code, asDouble(value))),
              pendingSync: true,
            ),
          );
      }
    }
    return items;
  }
}
