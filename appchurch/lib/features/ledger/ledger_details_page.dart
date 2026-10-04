import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/utils/formatters.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/value_row.dart';
import '../dashboard/dashboard_models.dart';
import '../expenses/expense_form_page.dart';
import '../revenues/revenue_form_page.dart';
import 'ledger_models.dart';
import 'ledger_service.dart';
import 'pay_payable_page.dart';
import 'widgets/reverse_dialog.dart';

const paymentMethodLabels = {
  'PIX': 'PIX',
  'CASH': 'Dinheiro em espécie',
  'TRANSFER': 'Transferência',
};

/// Detalhe de um lançamento do extrato, com as ações permitidas:
/// receita (editar/estornar), despesa paga (editar/estornar) e conta a
/// pagar (pagar/editar/cancelar). Lançamento de ciclo fechado não muda.
/// Retorna `true` ao fechar quando algo mudou.
class LedgerDetailsPage extends StatefulWidget {
  const LedgerDetailsPage({super.key, required this.api, required this.item});

  final ApiClient api;
  final LedgerItem item;

  @override
  State<LedgerDetailsPage> createState() => _LedgerDetailsPageState();
}

class _LedgerDetailsPageState extends State<LedgerDetailsPage> {
  late final LedgerService _service = LedgerService(widget.api);

  /// `null` enquanto verifica; `false` se o lançamento é de ciclo fechado.
  bool? _editable;
  bool _busy = false;

  LedgerItem get item => widget.item;

  @override
  void initState() {
    super.initState();
    _checkEditable();
  }

  Future<void> _checkEditable() async {
    final date = item.date;
    var editable = true;
    try {
      final closed = await _service.closedPeriods();
      editable =
          date == null ||
          !closed.any(
            (period) =>
                !date.isBefore(period.start) && !date.isAfter(period.end),
          );
    } catch (_) {
      // Sem a lista de ciclos: a API ainda recusa alterações em ciclo fechado.
    }
    if (mounted) setState(() => _editable = editable);
  }

  /// Abre outra tela; se ela retornar `true`, fecha o detalhe avisando mudança.
  Future<void> _openAndClose(Widget page) async {
    final changed = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => page));
    if (changed == true && mounted) Navigator.of(context).pop(true);
  }

  void _edit() {
    switch (item.kind) {
      case LedgerKind.revenue:
        _openAndClose(
          RevenueFormPage(
            api: widget.api,
            editing: RevenueDraft(
              id: item.id,
              fundCode: item.fundCode ?? 'OFERTAS_CULTO',
              date: item.date,
              description: item.description,
              pixAmount: item.pixAmount,
              cashAmount: item.cashAmount,
              categoryId: item.categoryId,
            ),
          ),
        );
      case LedgerKind.expense:
        _openAndClose(
          ExpenseFormPage(
            api: widget.api,
            editing: ExpenseDraft(
              id: item.payableId ?? item.id,
              paid: true,
              amount: item.amount,
              description: item.description,
              date: item.date,
              categoryId: item.categoryId,
              paymentMethod: item.paymentMethod,
              fundingSources: item.funds,
            ),
          ),
        );
      case LedgerKind.payable:
        _openAndClose(
          ExpenseFormPage(
            api: widget.api,
            editing: ExpenseDraft(
              id: item.id,
              paid: false,
              amount: item.amount,
              description: item.description,
              date: item.date,
              categoryId: item.categoryId,
              notificationDaysBefore: item.notificationDaysBefore,
            ),
          ),
        );
    }
  }

  Future<void> _reverse() async {
    final isPayable = item.kind == LedgerKind.payable;
    final choice = await showReverseDialog(
      context,
      title: switch (item.kind) {
        LedgerKind.revenue => 'Estornar receita',
        LedgerKind.expense => 'Estornar despesa',
        LedgerKind.payable => 'Cancelar conta a pagar',
      },
      message: isPayable
          ? 'A conta "${item.description}" deixa de existir. O motivo fica registrado.'
          : 'O lançamento de ${formatMoney(item.amount)} sai dos totais, mas continua '
                'registrado com o motivo para a prestação de contas.',
      askExpenseOutcome: item.kind == LedgerKind.expense,
      // Despesa lançada já paga: normalmente cancela; pagamento de conta:
      // normalmente a conta volta a ficar em aberto.
      initialCancelExpense: item.paidOnCreation,
      confirmLabel: isPayable ? 'Cancelar conta' : 'Confirmar estorno',
    );
    if (choice == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final result = switch (item.kind) {
        LedgerKind.revenue => await _service.reverseRevenue(
          item.id,
          choice.reason,
        ),
        LedgerKind.expense => await _service.reversePayment(
          item.id,
          choice.reason,
          cancelExpense: choice.cancelExpense,
        ),
        LedgerKind.payable => await _service.cancelPayable(
          item.id,
          choice.reason,
        ),
      };
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result == SendResult.sent
                ? (isPayable ? 'Conta cancelada.' : 'Lançamento estornado.')
                : 'Sem conexão: será enviado quando a conexão voltar.',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeApiError(error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (title, icon, color) = switch (item.kind) {
      LedgerKind.revenue => (
        item.fundCode == 'DIZIMOS' ? 'Dízimo' : 'Oferta',
        Icons.arrow_downward,
        Colors.green.shade700,
      ),
      LedgerKind.expense => (
        'Despesa paga',
        Icons.arrow_upward,
        theme.colorScheme.error,
      ),
      LedgerKind.payable => (
        'Conta a pagar',
        Icons.schedule,
        const Color(0xFFF57C00),
      ),
    };
    final rows = <Widget>[
      ValueRow(
        label: switch (item.kind) {
          LedgerKind.revenue => 'Data',
          LedgerKind.expense => 'Data do pagamento',
          LedgerKind.payable => 'Vencimento',
        },
        value: formatDate(item.date),
      ),
      ValueRow(
        label:
            item.kind == LedgerKind.revenue && item.fundCode != 'OFERTAS_CULTO'
            ? 'Contribuinte'
            : 'Descrição',
        value: item.description,
      ),
      if (item.kind == LedgerKind.revenue) ...[
        ValueRow(label: 'Fundo', value: fundNames[item.fundCode] ?? '-'),
        ValueRow(label: 'Tipo', value: item.category ?? '-'),
        if (item.pixAmount > 0)
          ValueRow(label: 'PIX', value: formatMoney(item.pixAmount)),
        if (item.cashAmount > 0)
          ValueRow(label: 'Dinheiro', value: formatMoney(item.cashAmount)),
      ] else
        ValueRow(label: 'Categoria', value: item.category ?? 'Sem categoria'),
      if (item.paymentMethod != null)
        ValueRow(
          label: 'Forma de pagamento',
          value: paymentMethodLabels[item.paymentMethod] ?? item.paymentMethod!,
        ),
      if (item.kind == LedgerKind.payable) ...[
        ValueRow(label: 'Valor da conta', value: formatMoney(item.amount)),
        ValueRow(
          label: 'Em aberto',
          value: formatMoney(item.remaining ?? item.amount),
          emphasized: true,
        ),
      ],
      if (item.pendingSync)
        const ValueRow(label: 'Situação', value: 'Aguardando sincronização'),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: theme.colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(icon, color: color, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    formatMoney(item.amount),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          SectionCard(title: 'Dados do lançamento', children: rows),
          if (item.kind == LedgerKind.expense)
            SectionCard(
              title: 'Origem do dinheiro (rateio)',
              icon: Icons.call_split,
              children: [
                if (item.funds.isEmpty)
                  const Text('Rateio não informado.')
                else
                  for (final MapEntry(:key, :value) in item.funds.entries)
                    ValueRow(
                      label: fundNames[key] ?? key,
                      value: formatMoney(value),
                    ),
              ],
            ),
          _Actions(
            item: item,
            editable: _editable,
            busy: _busy,
            onPay: () =>
                _openAndClose(PayPayablePage(api: widget.api, payable: item)),
            onEdit: _edit,
            onReverse: _reverse,
          ),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.item,
    required this.editable,
    required this.busy,
    required this.onPay,
    required this.onEdit,
    required this.onReverse,
  });

  final LedgerItem item;
  final bool? editable;
  final bool busy;
  final VoidCallback onPay;
  final VoidCallback onEdit;
  final VoidCallback onReverse;

  @override
  Widget build(BuildContext context) {
    if (item.pendingSync) {
      return const _Note(
        icon: Icons.cloud_upload_outlined,
        text:
            'Aguardando sincronização. Para alterar, espere o envio terminar.',
      );
    }
    if (editable == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (editable == false) {
      return const _Note(
        icon: Icons.lock_outline,
        text: 'Lançamento de ciclo fechado: não pode ser alterado.',
      );
    }
    final hasPayments =
        item.kind == LedgerKind.payable &&
        (item.remaining ?? item.amount) < item.amount - 0.005;
    final canEdit = switch (item.kind) {
      LedgerKind.revenue => true,
      LedgerKind.expense => item.paidOnCreation,
      LedgerKind.payable => !hasPayments,
    };
    final canReverse = item.kind != LedgerKind.payable || !hasPayments;
    final error = Theme.of(context).colorScheme.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (item.kind == LedgerKind.payable)
          FilledButton.icon(
            onPressed: busy ? null : onPay,
            icon: const Icon(Icons.payments_outlined),
            label: const Text('Pagar'),
          ),
        if (canEdit) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: busy ? null : onEdit,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Editar'),
          ),
        ],
        if (canReverse) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: busy ? null : onReverse,
            style: OutlinedButton.styleFrom(foregroundColor: error),
            icon: Icon(
              item.kind == LedgerKind.payable ? Icons.block : Icons.undo,
            ),
            label: Text(
              item.kind == LedgerKind.payable ? 'Cancelar conta' : 'Estornar',
            ),
          ),
        ],
        if (hasPayments)
          const _Note(
            icon: Icons.info_outline,
            text:
                'Conta com pagamento parcial: para alterar, estorne o pagamento '
                'na lista de saídas.',
          ),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(leading: Icon(icon), title: Text(text)),
    );
  }
}
