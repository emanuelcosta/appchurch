import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../shared/widgets/async_states.dart';
import '../../shared/widgets/pending_sync_note.dart';
import '../cycles/close_cycle_page.dart';
import '../cycles/cycles_service.dart';
import '../dashboard/dashboard_models.dart';
import '../dashboard/dashboard_service.dart';
import '../dashboard/widgets/cycle_selector.dart';
import '../dashboard/widgets/report_sections.dart';

/// Relatório do ciclo de prestação de contas no formato da aba
/// "RELATORIO_MENSAL" da planilha: Entradas, Despesas, Saldos e Repasses.
/// Abre no ciclo atual, permite consultar ciclos anteriores e fechar o ciclo.
class CycleReportPage extends StatefulWidget {
  const CycleReportPage({super.key, required this.api});

  final ApiClient api;

  @override
  State<CycleReportPage> createState() => _CycleReportPageState();
}

class _CycleReportPageState extends State<CycleReportPage> {
  late final DashboardService _service = DashboardService(widget.api);
  late Future<DashboardData> _data;
  String? _cycleId;

  @override
  void initState() {
    super.initState();
    _data = _service.load();
  }

  Future<void> _reload() async {
    final future = _service.load(cycleId: _cycleId);
    setState(() {
      _data = future;
    });
    await future.then((_) {}, onError: (_) {});
  }

  void _selectCycle(String cycleId) {
    _cycleId = cycleId;
    _reload();
  }

  Future<void> _closeCycle(CycleInfo cycle) async {
    final closed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CloseCyclePage(api: widget.api, cycle: cycle),
      ),
    );
    if (closed == true) {
      _cycleId = null; // volta para o novo ciclo atual
      await _reload();
    }
  }

  Future<void> _openCycle(DateTime? suggestedStart) async {
    final start = await showDatePicker(
      context: context,
      helpText: 'Início do novo ciclo',
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      initialDate: suggestedStart ?? DateTime.now(),
    );
    if (start == null || !mounted) return;
    try {
      await CyclesService(widget.api).open(start);
      _cycleId = null;
      await _reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeApiError(error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Relatório do ciclo')),
      body: _body(),
    );
  }

  Widget _body() {
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
        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (data.cycles.isNotEmpty) ...[
                CycleSelector(
                  cycles: data.cycles,
                  selectedId: data.cycle?.id,
                  onChanged: _selectCycle,
                ),
                const SizedBox(height: 8),
              ],
              _CycleActions(
                data: data,
                onClose: _closeCycle,
                onOpen: _openCycle,
              ),
              if (data.cycle == null)
                const EmptyMessage(
                  icon: Icons.event_busy,
                  message: 'Nenhum ciclo de prestação de contas cadastrado.',
                )
              else ...[
                PendingSyncNote(api: widget.api),
                EntriesSection(data: data),
                ExpensesSection(data: data),
                BalancesSection(data: data),
                TransfersSection(data: data),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// "Fechar ciclo" no ciclo aberto, ou "Iniciar ciclo" quando não há ciclo aberto.
class _CycleActions extends StatelessWidget {
  const _CycleActions({
    required this.data,
    required this.onClose,
    required this.onOpen,
  });

  final DashboardData data;
  final ValueChanged<CycleInfo> onClose;
  final ValueChanged<DateTime?> onOpen;

  @override
  Widget build(BuildContext context) {
    final cycle = data.cycle;
    final hasOpenCycle = data.cycles.any((item) => item.isOpen);
    if (cycle != null && cycle.isOpen) {
      return Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: () => onClose(cycle),
          icon: const Icon(Icons.lock_outline),
          label: const Text('Fechar ciclo'),
        ),
      );
    }
    if (hasOpenCycle) return const SizedBox(height: 8);
    final lastEnd = data.cycles
        .map((item) => item.endDate)
        .whereType<DateTime>()
        .fold<DateTime?>(
          null,
          (latest, date) =>
              latest == null || date.isAfter(latest) ? date : latest,
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FilledButton.icon(
        onPressed: () => onOpen(lastEnd?.add(const Duration(days: 1))),
        icon: const Icon(Icons.play_arrow),
        label: const Text('Iniciar novo ciclo de prestação de contas'),
      ),
    );
  }
}
