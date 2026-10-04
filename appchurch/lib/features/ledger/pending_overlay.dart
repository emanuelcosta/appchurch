import '../../core/utils/json.dart';
import 'ledger_models.dart';

/// Operação da fila offline (caminho da API e corpo enviado).
typedef PendingOperation = ({String path, Map<String, dynamic> body});

/// Aplica sobre o extrato do servidor o que foi feito offline e ainda não
/// sincronizou (na ordem em que foi feito): lançamentos novos, edições,
/// pagamentos, estornos e cancelamentos. Os itens afetados ficam marcados
/// como "aguardando sincronização". Só ajusta a exibição; quem calcula e
/// valida de verdade é a API, quando a fila for enviada.
List<LedgerItem> applyPendingOperations(
  List<LedgerItem> serverItems,
  List<PendingOperation> operations,
) {
  final items = [...serverItems];

  int indexWhere(bool Function(LedgerItem item) test) => items.indexWhere(test);

  void upsert(LedgerItem item, bool Function(LedgerItem other) same) {
    final index = indexWhere(same);
    if (index >= 0) {
      items[index] = item;
    } else {
      items.add(item);
    }
  }

  for (final (:path, :body) in operations) {
    final segments = path.split('/');
    switch (segments) {
      case ['finance', 'revenues']:
        final item = _revenueFrom(body);
        upsert(item, (other) => other.id == item.id);

      case ['finance', 'expenses']:
        final id = asString(body['id']) ?? '';
        if (body['status'] == 'PAYABLE') {
          final item = _payableFrom(body);
          upsert(
            item,
            (other) => other.kind == LedgerKind.payable && other.id == id,
          );
        } else {
          final index = indexWhere(
            (other) =>
                other.kind == LedgerKind.expense && other.payableId == id,
          );
          final current = index >= 0 ? items[index] : null;
          final item = _expenseFrom(body, paymentId: current?.id ?? id);
          if (index >= 0) {
            items[index] = item;
          } else {
            items.add(item);
          }
        }

      case ['finance', 'payables', final payableId, 'pay']:
        final amount = asDouble(body['amount']);
        final index = indexWhere(
          (other) => other.kind == LedgerKind.payable && other.id == payableId,
        );
        final payable = index >= 0 ? items[index] : null;
        if (payable != null) {
          final remaining = (payable.remaining ?? payable.amount) - amount;
          if (remaining <= 0.005) {
            items.removeAt(index);
          } else {
            items[index] = payable.copyWith(
              remaining: remaining,
              pendingSync: true,
            );
          }
        }
        items.add(
          LedgerItem(
            id: asString(body['paymentId']) ?? asString(body['id']) ?? '',
            kind: LedgerKind.expense,
            date: asDate(body['paymentDate']),
            description: payable?.description ?? 'Pagamento de conta',
            amount: amount,
            category: payable?.category,
            categoryId: payable?.categoryId,
            paymentMethod: asString(body['paymentMethod']),
            funds: _funds(body['fundingSources']),
            payableId: payableId,
            pendingSync: true,
          ),
        );

      case ['finance', 'revenues', final entryId, 'reverse']:
        items.removeWhere(
          (other) => other.kind == LedgerKind.revenue && other.id == entryId,
        );

      case ['finance', 'payments', final paymentId, 'reverse']:
        final index = indexWhere(
          (other) => other.kind == LedgerKind.expense && other.id == paymentId,
        );
        if (index < 0) break;
        final payment = items.removeAt(index);
        if (body['cancelExpense'] == false && payment.payableId != null) {
          final payableIndex = indexWhere(
            (other) =>
                other.kind == LedgerKind.payable &&
                other.id == payment.payableId,
          );
          if (payableIndex >= 0) {
            final payable = items[payableIndex];
            items[payableIndex] = payable.copyWith(
              remaining: (payable.remaining ?? 0) + payment.amount,
              pendingSync: true,
            );
          } else {
            items.add(
              payment.copyWith(
                id: payment.payableId,
                kind: LedgerKind.payable,
                remaining: payment.amount,
                funds: const {},
                pendingSync: true,
              ),
            );
          }
        }

      case ['finance', 'payables', final payableId, 'cancel']:
        items.removeWhere(
          (other) => other.kind == LedgerKind.payable && other.id == payableId,
        );
    }
  }
  return items;
}

Map<String, double> _funds(Object? value) =>
    asMap(value).map((code, amount) => MapEntry(code, asDouble(amount)));

LedgerItem _revenueFrom(Map<String, dynamic> body) => LedgerItem(
  id: asString(body['id']) ?? '',
  kind: LedgerKind.revenue,
  date: asDate(body['date']),
  description: asString(body['description']) ?? 'Receita',
  amount: asDouble(body['pixAmount']) + asDouble(body['cashAmount']),
  fundCode: asString(body['fundCode']),
  categoryId: asString(body['categoryId']),
  pixAmount: asDouble(body['pixAmount']),
  cashAmount: asDouble(body['cashAmount']),
  pendingSync: true,
);

LedgerItem _payableFrom(Map<String, dynamic> body) => LedgerItem(
  id: asString(body['id']) ?? '',
  kind: LedgerKind.payable,
  date: asDate(body['dueDate']),
  description: asString(body['description']) ?? 'Conta a pagar',
  amount: asDouble(body['amount']),
  remaining: asDouble(body['amount']),
  categoryId: asString(body['categoryId']),
  notificationDaysBefore: body['notificationDaysBefore'] is num
      ? (body['notificationDaysBefore'] as num).toInt()
      : null,
  pendingSync: true,
);

LedgerItem _expenseFrom(
  Map<String, dynamic> body, {
  required String paymentId,
}) => LedgerItem(
  id: paymentId,
  kind: LedgerKind.expense,
  date: asDate(body['paymentDate']),
  description: asString(body['description']) ?? 'Despesa',
  amount: asDouble(body['amount']),
  categoryId: asString(body['categoryId']),
  paymentMethod: asString(body['paymentMethod']),
  funds: _funds(body['fundingSources']),
  payableId: asString(body['id']),
  paidOnCreation: true,
  pendingSync: true,
);
