import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/local/app_database.dart';
import '../../core/sync/sync_service.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/json.dart';
import '../../shared/widgets/async_states.dart';
import '../expenses/expense_form_page.dart';
import '../revenues/revenue_form_page.dart';

/// Envios que a API recusou (ex.: data em ciclo fechado, dado inválido).
/// O usuário corrige no formulário, tenta de novo ou descarta.
class SyncIssuesPage extends StatefulWidget {
  const SyncIssuesPage({super.key, required this.api, required this.sync});

  final ApiClient api;
  final SyncService sync;

  @override
  State<SyncIssuesPage> createState() => _SyncIssuesPageState();
}

class _SyncIssuesPageState extends State<SyncIssuesPage> {
  late Future<List<SyncOperation>> _issues = widget.sync.rejectedOperations();

  void _reload() => setState(() {
    _issues = widget.sync.rejectedOperations();
  });

  Future<void> _retry(SyncOperation operation) async {
    await widget.sync.retry(operation.id);
    if (mounted) _reload();
  }

  Future<void> _discard(SyncOperation operation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Descartar envio?'),
        content: const Text(
          'Este lançamento não será enviado e não entrará na tesouraria.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.sync.discard(operation.id);
    if (mounted) _reload();
  }

  /// Abre o formulário preenchido; salvo com o mesmo id, o envio recusado é
  /// substituído pelo corrigido.
  Future<void> _fix(SyncOperation operation, Widget form) async {
    final saved = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => form));
    if (saved == true) {
      await widget.sync.discard(operation.id);
      if (mounted) _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Envios recusados')),
      body: FutureBuilder<List<SyncOperation>>(
        future: _issues,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final issues = snapshot.data ?? [];
          if (issues.isEmpty) {
            return const EmptyMessage(
              icon: Icons.check_circle_outline,
              message: 'Nenhum envio recusado.',
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'A API não aceitou os lançamentos abaixo. Corrija, tente de '
                'novo ou descarte cada um.',
              ),
              const SizedBox(height: 12),
              for (final operation in issues)
                _IssueCard(
                  issue: SyncIssue.from(operation),
                  onRetry: () => _retry(operation),
                  onDiscard: () => _discard(operation),
                  onFix: _fixFormFor(operation) == null
                      ? null
                      : () => _fix(operation, _fixFormFor(operation)!),
                ),
            ],
          );
        },
      ),
    );
  }

  /// Formulário de correção para receitas e despesas; outros só reenviam.
  Widget? _fixFormFor(SyncOperation operation) {
    final body = asMap(operation.payload['body']);
    final id = asString(body['id']);
    if (id == null) return null;
    switch (operation.payload['path']) {
      case 'finance/revenues':
        return RevenueFormPage(
          api: widget.api,
          editing: RevenueDraft(
            id: id,
            fundCode: asString(body['fundCode']) ?? 'OFERTAS_CULTO',
            date: asDate(body['date']),
            description: asString(body['description']) ?? '',
            pixAmount: asDouble(body['pixAmount']),
            cashAmount: asDouble(body['cashAmount']),
            categoryId: asString(body['categoryId']),
          ),
        );
      case 'finance/expenses':
        final paid = body['status'] != 'PAYABLE';
        return ExpenseFormPage(
          api: widget.api,
          editing: ExpenseDraft(
            id: id,
            paid: paid,
            amount: asDouble(body['amount']),
            description: asString(body['description']) ?? '',
            date: asDate(paid ? body['paymentDate'] : body['dueDate']),
            categoryId: asString(body['categoryId']),
            paymentMethod: asString(body['paymentMethod']),
            fundingSources: asMap(
              body['fundingSources'],
            ).map((code, value) => MapEntry(code, asDouble(value))),
          ),
        );
    }
    return null;
  }
}

/// Resumo legível de um envio recusado.
class SyncIssue {
  const SyncIssue({
    required this.kind,
    required this.title,
    required this.error,
    this.amount,
    this.date,
  });

  factory SyncIssue.from(SyncOperation operation) {
    final path = operation.payload['path'] as String? ?? '';
    final body = asMap(operation.payload['body']);
    final kind = switch (path) {
      'finance/revenues' => 'Receita',
      'finance/expenses' => 'Despesa',
      'finance/members' => 'Cadastro de membro',
      _ when path.endsWith('/pay') => 'Pagamento de conta',
      _ when path.endsWith('/reverse') => 'Estorno',
      _ when path.endsWith('/cancel') => 'Cancelamento de conta',
      _ => 'Envio',
    };
    final amount = body.containsKey('pixAmount')
        ? asDouble(body['pixAmount']) + asDouble(body['cashAmount'])
        : body.containsKey('amount')
        ? asDouble(body['amount'])
        : null;
    return SyncIssue(
      kind: kind,
      title:
          asString(body['description']) ??
          asString(body['fullName']) ??
          asString(body['reason']) ??
          kind,
      amount: amount,
      date: asDate(body['date'] ?? body['paymentDate'] ?? body['dueDate']),
      error: operation.lastError ?? 'Recusado pela API.',
    );
  }

  final String kind;
  final String title;
  final double? amount;
  final DateTime? date;
  final String error;
}

class _IssueCard extends StatelessWidget {
  const _IssueCard({
    required this.issue,
    required this.onRetry,
    required this.onDiscard,
    this.onFix,
  });

  final SyncIssue issue;
  final VoidCallback onRetry;
  final VoidCallback onDiscard;
  final VoidCallback? onFix;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              [
                issue.kind,
                if (issue.date != null) formatDate(issue.date),
                if (issue.amount != null) formatMoney(issue.amount!),
              ].join(' • '),
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 4),
            Text(issue.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline, size: 18, color: colors.error),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    issue.error,
                    style: TextStyle(color: colors.error),
                  ),
                ),
              ],
            ),
            Wrap(
              alignment: WrapAlignment.end,
              children: [
                TextButton(
                  onPressed: onDiscard,
                  child: const Text('Descartar'),
                ),
                TextButton(
                  onPressed: onRetry,
                  child: const Text('Tentar de novo'),
                ),
                if (onFix != null)
                  FilledButton.tonal(
                    onPressed: onFix,
                    child: const Text('Corrigir'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
