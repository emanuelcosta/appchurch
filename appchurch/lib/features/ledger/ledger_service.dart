import 'package:flutter/material.dart' show DateTimeRange;

import '../../core/api/api_client.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/json.dart';
import 'ledger_models.dart';
import 'pending_overlay.dart';

/// Extrato do ciclo (receitas, despesas e contas a pagar) e pagamento de
/// contas. Lançamentos feitos offline aparecem como "aguardando
/// sincronização" até a fila ser enviada.
class LedgerService {
  const LedgerService(this._api);

  final ApiClient _api;

  /// Extrato do ciclo [cycleId] (padrão: o aberto) ou, com [period], de
  /// todos os lançamentos entre as datas, em qualquer ciclo.
  Future<LedgerData> load({String? cycleId, DateTimeRange? period}) async =>
      (await loadWithPending(cycleId: cycleId, period: period)).merged;

  /// Extrato como está na API ([server]) e com a fila offline aplicada
  /// ([merged]); a diferença entre os dois é o que ainda não sincronizou.
  Future<({LedgerData server, LedgerData merged})> loadWithPending({
    String? cycleId,
    DateTimeRange? period,
  }) async {
    final data = await _api.get(
      'finance/ledger',
      query: {
        'congregationId': _api.congregationId,
        if (period == null) 'cycleId': ?cycleId,
        if (period != null) 'from': toIsoDate(period.start),
        if (period != null) 'to': toIsoDate(period.end),
      },
    );
    if (data is! Map) {
      throw StateError('A API retornou uma resposta inválida para o extrato.');
    }
    final ledger = LedgerData.fromJson(Map<String, dynamic>.from(data));
    return (
      server: ledger,
      merged: ledger.withItems(
        applyPendingOperations(ledger.items, await _pendingOperations()),
      ),
    );
  }

  /// Paga (total ou parcialmente) uma conta; sem conexão, vai para a fila.
  Future<SendResult> pay(String payableId, Map<String, Object?> body) =>
      _api.send('finance/payables/$payableId/pay', {
        ...body,
        // Identifica o pagamento na fila (permite desfazer antes de enviar).
        'id': body['paymentId'],
        'congregationId': _api.congregationId,
      });

  /// Desfaz o que ainda está na fila para este lançamento (não será enviado).
  Future<void> discardPending(String entityId) async =>
      _api.database?.discardPendingFor(_api.congregationId, entityId);

  /// Estorna uma receita (motivo vai para a auditoria). Funciona offline.
  Future<SendResult> reverseRevenue(String entryId, String reason) => _api.send(
    'finance/revenues/$entryId/reverse',
    {'id': entryId, 'congregationId': _api.congregationId, 'reason': reason},
  );

  /// Estorna o pagamento de uma despesa: cancela a despesa ou mantém a
  /// conta em aberto. Funciona offline.
  Future<SendResult> reversePayment(
    String paymentId,
    String reason, {
    required bool cancelExpense,
  }) => _api.send('finance/payments/$paymentId/reverse', {
    'id': paymentId,
    'congregationId': _api.congregationId,
    'reason': reason,
    'cancelExpense': cancelExpense,
  });

  /// Cancela uma conta a pagar sem pagamentos. Funciona offline.
  Future<SendResult> cancelPayable(String payableId, String reason) =>
      _api.send('finance/payables/$payableId/cancel', {
        'id': payableId,
        'congregationId': _api.congregationId,
        'reason': reason,
      });

  /// Ciclos fechados (para saber se um lançamento ainda pode ser alterado).
  Future<List<({DateTime start, DateTime end})>> closedPeriods() async {
    final data = await _api.get(
      'finance/accountability-cycles',
      query: {'congregationId': _api.congregationId},
    );
    return [
      for (final cycle in asMapList(data))
        if (cycle['status'] == 'CLOSED' &&
            asDate(cycle['startDate']) != null &&
            asDate(cycle['endDate']) != null)
          (start: asDate(cycle['startDate'])!, end: asDate(cycle['endDate'])!),
    ];
  }

  /// Gravações na fila offline, na ordem em que foram feitas.
  Future<List<PendingOperation>> _pendingOperations() async {
    final database = _api.database;
    if (database == null) return [];
    final operations = await database.pendingOperations(_api.congregationId);
    return [
      for (final operation in operations)
        if (operation.entityType == apiRequestEntity &&
            operation.payload['path'] is String)
          (
            path: operation.payload['path'] as String,
            body: asMap(operation.payload['body']),
          ),
    ];
  }
}
