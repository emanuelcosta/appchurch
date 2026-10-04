import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../ledger_models.dart';

/// Linha do extrato: receita (verde), despesa (vermelha) ou conta a pagar.
class LedgerTile extends StatelessWidget {
  const LedgerTile({
    super.key,
    required this.item,
    required this.onTap,
    this.today,
  });

  final LedgerItem item;
  final VoidCallback onTap;
  final DateTime? today;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (icon, color, sign) = switch (item.kind) {
      LedgerKind.revenue => (Icons.arrow_downward, Colors.green.shade700, '+'),
      LedgerKind.expense => (Icons.arrow_upward, colors.error, '-'),
      LedgerKind.payable => (Icons.schedule, const Color(0xFFF57C00), ''),
    };
    final subtitle = [
      if (item.pendingSync) 'Aguardando sincronização',
      if (item.kind == LedgerKind.payable) _dueText(),
      item.tag,
      if (item.kind == LedgerKind.expense && item.funds.isNotEmpty)
        item.fundsLabel,
    ].join(' • ');
    final value = item.kind == LedgerKind.payable
        ? item.remaining ?? item.amount
        : item.amount;
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(
            item.pendingSync ? Icons.cloud_upload_outlined : icon,
            color: color,
          ),
        ),
        title: Text(
          item.description,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: Text(
          '$sign${formatMoney(value)}',
          style: TextStyle(fontWeight: FontWeight.bold, color: color),
        ),
      ),
    );
  }

  String _dueText() {
    final due = item.date;
    if (due == null) return 'Sem vencimento';
    final now = today ?? DateTime.now();
    final days = DateTime(
      due.year,
      due.month,
      due.day,
    ).difference(DateTime(now.year, now.month, now.day)).inDays;
    if (days < 0) return 'Vencida há ${-days} dia(s)';
    if (days == 0) return 'Vence hoje';
    if (days == 1) return 'Vence amanhã';
    return 'Vence em ${formatDate(due)}';
  }
}
