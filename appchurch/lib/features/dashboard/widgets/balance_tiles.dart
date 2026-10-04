import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../dashboard_models.dart';

/// Saldos do ciclo em destaque, para leitura rápida no início do app.
class BalanceTiles extends StatelessWidget {
  const BalanceTiles({super.key, required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final tithe = data.tithe;
    final tiles = [
      _BalanceTile(
        icon: Icons.church,
        label: 'Ofertas de culto',
        value: data.fund('OFERTAS_CULTO').closing,
      ),
      _BalanceTile(
        icon: Icons.account_balance,
        label: 'Ofertas alçadas',
        value: data.fund('OFERTAS_ALCADAS').closing,
      ),
      _BalanceTile(
        icon: Icons.volunteer_activism,
        label: 'Dízimos',
        value: tithe?.balanceBeforeTransfers ?? data.fund('DIZIMOS').closing,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        // Uma coluna em telas estreitas; três lado a lado em telas largas.
        final wide = constraints.maxWidth >= 600;
        return wide
            ? Row(children: [for (final tile in tiles) Expanded(child: tile)])
            : Column(children: tiles);
      },
    );
  }
}

class _BalanceTile extends StatelessWidget {
  const _BalanceTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final negative = value < 0;
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.onPrimaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                formatMoney(value),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: negative
                      ? theme.colorScheme.error
                      : theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
