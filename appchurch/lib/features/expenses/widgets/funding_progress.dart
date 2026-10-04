import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../expense_models.dart';

/// Barra que mostra quanto do valor da despesa já foi coberto pelas fontes
/// e quanto falta (ou quanto passou).
class FundingProgress extends StatelessWidget {
  const FundingProgress({super.key, required this.split});

  final FundingSplit split;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (color, icon, message) = switch (split.status) {
      SplitStatus.empty => (
        colors.outline,
        Icons.info_outline,
        'Informe o valor da despesa para distribuir entre as fontes.',
      ),
      SplitStatus.missing => (
        const Color(0xFFF57C00),
        Icons.pending_outlined,
        'Faltam ${formatMoney(split.remaining)} para completar ${formatMoney(split.total)}',
      ),
      SplitStatus.complete => (
        Colors.green.shade700,
        Icons.check_circle,
        'Valor completo: ${formatMoney(split.total)}',
      ),
      SplitStatus.exceeded => (
        colors.error,
        Icons.error_outline,
        'Passou ${formatMoney(-split.remaining)} do valor da despesa',
      ),
    };
    final progress = split.total <= 0
        ? 0.0
        : (split.allocated / split.total).clamp(0.0, 1.0);
    return Card(
      color: color.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(color: color, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                color: color,
                backgroundColor: color.withValues(alpha: 0.2),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Distribuído: ${formatMoney(split.allocated)} de ${formatMoney(split.total)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
