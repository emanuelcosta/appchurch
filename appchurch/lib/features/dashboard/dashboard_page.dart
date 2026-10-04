import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/settings/due_alert_settings.dart';
import '../../core/utils/formatters.dart';
import '../../shared/widgets/async_states.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/value_row.dart';
import 'dashboard_models.dart';
import 'dashboard_service.dart';
import 'widgets/balance_tiles.dart';
import 'widgets/pending_payables_card.dart';

/// Início do app: visão rápida do ciclo atual. O detalhamento fica no
/// relatório do ciclo ([onOpenReport]).
class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.api,
    required this.alertSettings,
    required this.onOpenReport,
    this.today,
  });

  final ApiClient api;
  final ValueListenable<DueAlertSettings> alertSettings;
  final VoidCallback onOpenReport;

  /// Data usada como "hoje"; permite testes determinísticos.
  final DateTime? today;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late final DashboardService _service = DashboardService(widget.api);
  late Future<DashboardData> _data = _service.load();

  Future<void> _reload() async {
    final future = _service.load();
    setState(() {
      _data = future;
    });
    await future.then((_) {}, onError: (_) {});
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DashboardData>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: ErrorRetry(
              message: describeApiError(snapshot.error!),
              onRetry: _reload,
            ),
          );
        }
        final data = snapshot.data!;
        final cycle = data.cycle;
        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ValueListenableBuilder(
                valueListenable: widget.alertSettings,
                builder: (context, settings, _) => PendingPayablesCard(
                  payables: data.pendingPayables,
                  settings: settings,
                  today: widget.today ?? DateTime.now(),
                ),
              ),
              if (cycle == null)
                EmptyMessage(
                  icon: Icons.event_busy,
                  message:
                      'Nenhum ciclo de prestação de contas aberto. '
                      'Abra um ciclo pelo relatório do ciclo.',
                )
              else ...[
                Text(
                  'Saldos do ciclo atual',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(cycle.label),
                const SizedBox(height: 8),
                BalanceTiles(data: data),
                const SizedBox(height: 8),
                _CycleSummary(data: data),
              ],
              FilledButton.tonalIcon(
                onPressed: widget.onOpenReport,
                icon: const Icon(Icons.assessment_outlined),
                label: const Text('Ver relatório do ciclo'),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Totais do ciclo: entradas, despesas e repasses previstos.
class _CycleSummary extends StatelessWidget {
  const _CycleSummary({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    double sum(double Function(FundBalance fund) pick) =>
        data.funds.values.fold(0, (total, fund) => total + pick(fund));
    final transfers = data.transfers.fold<double>(
      0,
      (total, item) => total + item.amount,
    );
    return SectionCard(
      title: 'Resumo do ciclo',
      icon: Icons.summarize_outlined,
      children: [
        ValueRow(
          label: 'Entradas',
          value: formatMoney(sum((fund) => fund.revenue)),
        ),
        ValueRow(
          label: 'Despesas',
          value: formatMoney(sum((fund) => fund.expenses)),
        ),
        ValueRow(label: 'Repasses previstos', value: formatMoney(transfers)),
      ],
    );
  }
}
