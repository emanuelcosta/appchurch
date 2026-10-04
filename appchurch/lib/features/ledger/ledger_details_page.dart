import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/utils/formatters.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/value_row.dart';
import '../dashboard/dashboard_models.dart';
import 'ledger_models.dart';
import 'pay_payable_page.dart';

const paymentMethodLabels = {
  'PIX': 'PIX',
  'CASH': 'Dinheiro em espécie',
  'TRANSFER': 'Transferência',
};

/// Detalhe de um lançamento do extrato. Conta a pagar tem o botão "Pagar".
/// Retorna `true` ao fechar quando algo mudou (ex.: conta paga).
class LedgerDetailsPage extends StatelessWidget {
  const LedgerDetailsPage({super.key, required this.api, required this.item});

  final ApiClient api;
  final LedgerItem item;

  Future<void> _pay(BuildContext context) async {
    final paid = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PayPayablePage(api: api, payable: item),
      ),
    );
    if (paid == true && context.mounted) Navigator.of(context).pop(true);
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
          if (item.kind == LedgerKind.payable && !item.pendingSync)
            FilledButton.icon(
              onPressed: () => _pay(context),
              icon: const Icon(Icons.payments_outlined),
              label: const Text('Pagar'),
            ),
        ],
      ),
    );
  }
}
