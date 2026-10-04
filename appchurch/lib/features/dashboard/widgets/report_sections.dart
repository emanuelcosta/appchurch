import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/value_row.dart';
import '../dashboard_models.dart';

/// Blocos do dashboard na ordem da aba "RELATORIO_MENSAL" da planilha:
/// Entradas, Despesas, Saldos e Repasses.

class EntriesSection extends StatelessWidget {
  const EntriesSection({super.key, required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final culto = data.fund('OFERTAS_CULTO');
    final alcadas = data.fund('OFERTAS_ALCADAS');
    final alcadasTypes = data.categoriesOf('OFERTAS_ALCADAS');
    final tithe = data.fund('DIZIMOS');
    final subtitle = Theme.of(context).textTheme.titleSmall;
    return SectionCard(
      title: 'Entradas',
      icon: Icons.trending_up,
      children: [
        Text('Ofertas de culto', style: subtitle),
        ValueRow(label: 'Saldo anterior', value: formatMoney(culto.opening)),
        ValueRow(label: 'Ofertas de cultos', value: formatMoney(culto.revenue)),
        ValueRow(
          label: 'Total de ofertas de culto',
          value: formatMoney(culto.opening + culto.revenue),
          emphasized: true,
        ),
        const Divider(),
        Text('Ofertas alçadas', style: subtitle),
        ValueRow(label: 'Saldo anterior', value: formatMoney(alcadas.opening)),
        ValueRow(label: 'Ofertas alçadas', value: formatMoney(alcadas.revenue)),
        if (alcadasTypes.length > 1)
          for (final type in alcadasTypes)
            ValueRow(
              label: type.category,
              value: formatMoney(type.amount),
              indent: true,
            ),
        ValueRow(
          label: 'Total de ofertas alçadas',
          value: formatMoney(alcadas.opening + alcadas.revenue),
          emphasized: true,
        ),
        const Divider(),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          shape: const Border(),
          title: Text('Dízimos', style: subtitle),
          subtitle: Text('${data.titheEntries.length} lançamento(s)'),
          trailing: Text(
            formatMoney(tithe.revenue),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          children: [
            for (final entry in data.titheEntries)
              ValueRow(
                label: '${formatDate(entry.date)} · ${entry.name}',
                value: formatMoney(entry.amount),
                indent: true,
              ),
          ],
        ),
        ValueRow(
          label: 'Total de dízimos',
          value: formatMoney(tithe.revenue),
          emphasized: true,
        ),
      ],
    );
  }
}

class ExpensesSection extends StatelessWidget {
  const ExpensesSection({super.key, required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final culto = data.fund('OFERTAS_CULTO').expenses;
    final alcadas = data.fund('OFERTAS_ALCADAS').expenses;
    final tithe = data.fund('DIZIMOS').expenses;
    return SectionCard(
      title: 'Despesas',
      icon: Icons.trending_down,
      children: [
        ValueRow(label: 'Saídas ofertas de cultos', value: formatMoney(culto)),
        ValueRow(label: 'Saídas ofertas alçadas', value: formatMoney(alcadas)),
        ValueRow(label: 'Saídas dízimos', value: formatMoney(tithe)),
        const Divider(),
        ValueRow(
          label: 'Total de despesas',
          value: formatMoney(culto + alcadas + tithe),
          emphasized: true,
        ),
      ],
    );
  }
}

class BalancesSection extends StatelessWidget {
  const BalancesSection({super.key, required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    Color? color(double value) => value < 0 ? Colors.red : null;
    final rows = {
      'Ofertas de culto': data.fund('OFERTAS_CULTO').closing,
      'Ofertas alçadas': data.fund('OFERTAS_ALCADAS').closing,
      'Dízimos (antes dos repasses)':
          data.tithe?.balanceBeforeTransfers ?? data.fund('DIZIMOS').closing,
    };
    return SectionCard(
      title: 'Saldos',
      icon: Icons.account_balance_wallet_outlined,
      children: [
        for (final MapEntry(:key, :value) in rows.entries)
          ValueRow(
            label: key,
            value: formatMoney(value),
            emphasized: true,
            valueColor: color(value),
          ),
      ],
    );
  }
}

class TransfersSection extends StatelessWidget {
  const TransfersSection({super.key, required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final tithe = data.tithe;
    final percentage = tithe == null
        ? ''
        : ' (${tithe.leaderPercentage.toStringAsFixed(tithe.leaderPercentage % 1 == 0 ? 0 : 2)}%)';
    return SectionCard(
      title: 'Repasses',
      icon: Icons.send_outlined,
      children: [
        for (final transfer in data.transfers)
          ValueRow(
            label: transfer.destinationName == 'Dirigente'
                ? 'Dirigente$percentage · ${transfer.statusLabel}'
                : '${transfer.destinationName} · ${transfer.statusLabel}',
            value: formatMoney(transfer.amount),
            valueColor: transfer.amount < 0 ? Colors.red : null,
          ),
        const Divider(),
        ValueRow(
          label: 'Total de repasses',
          value: formatMoney(
            data.transfers.fold(0, (sum, item) => sum + item.amount),
          ),
          emphasized: true,
        ),
        if (tithe?.headquartersNegative ?? false)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'As despesas pagas com dízimos superam o valor disponível para a sede. '
              'O ciclo não poderá ser fechado até a revisão.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    );
  }
}
