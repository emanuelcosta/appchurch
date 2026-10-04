import 'package:flutter/material.dart';

import '../../../core/settings/due_alert_settings.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/pulsing_border.dart';
import '../dashboard_models.dart';

const _warningColor = Color(0xFFF57C00); // laranja

/// Destaque no topo do dashboard: contas não pagas que vencem até o fim do
/// mês seguinte. A borda pulsa em laranja (prazo de aviso) ou vermelho
/// (prazo urgente ou conta vencida), conforme os dias configurados.
class PendingPayablesCard extends StatelessWidget {
  const PendingPayablesCard({
    super.key,
    required this.payables,
    required this.settings,
    required this.today,
  });

  final List<PendingPayable> payables;
  final DueAlertSettings settings;
  final DateTime today;

  Color? _colorOf(DueAlertLevel level, ColorScheme colors) => switch (level) {
    DueAlertLevel.urgent => colors.error,
    DueAlertLevel.warning => _warningColor,
    DueAlertLevel.none => null,
  };

  String _dueText(PendingPayable payable) {
    final due = payable.dueDate;
    if (due == null) return 'Sem vencimento';
    final days = DateTime(
      due.year,
      due.month,
      due.day,
    ).difference(DateTime(today.year, today.month, today.day)).inDays;
    final date = formatDate(due);
    if (days < 0) return 'VENCIDA há ${-days} dia(s) · $date';
    if (days == 0) return 'Vence HOJE · $date';
    if (days == 1) return 'Vence amanhã · $date';
    return 'Vence em $days dias · $date';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final levels = [
      for (final payable in payables) settings.levelFor(payable.dueDate, today),
    ];
    final cardLevel = levels.contains(DueAlertLevel.urgent)
        ? DueAlertLevel.urgent
        : levels.contains(DueAlertLevel.warning)
        ? DueAlertLevel.warning
        : DueAlertLevel.none;
    final total = payables.fold<double>(0, (sum, item) => sum + item.remaining);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: PulsingBorder(
        color: _colorOf(cardLevel, colors),
        child: Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      cardLevel == DueAlertLevel.none
                          ? Icons.event_note
                          : Icons.warning_amber,
                      color: _colorOf(cardLevel, colors) ?? colors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Contas pendentes vencendo',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (payables.isNotEmpty)
                      Text(
                        formatMoney(total),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                if (payables.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text('Sem contas próximas a vencer.'),
                  )
                else
                  for (var i = 0; i < payables.length; i++)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.circle,
                        size: 12,
                        color: _colorOf(levels[i], colors) ?? colors.outline,
                      ),
                      minLeadingWidth: 12,
                      title: Text(payables[i].description),
                      subtitle: Text(
                        _dueText(payables[i]),
                        style: TextStyle(
                          color: _colorOf(levels[i], colors),
                          fontWeight: levels[i] == DueAlertLevel.urgent
                              ? FontWeight.bold
                              : null,
                        ),
                      ),
                      trailing: Text(
                        formatMoney(payables[i].remaining),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
