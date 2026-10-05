import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/utils/formatters.dart';
import '../../shared/widgets/section_card.dart';
import '../dashboard/dashboard_models.dart';
import '../dashboard/dashboard_service.dart';
import '../dashboard/widgets/cycle_selector.dart';
import '../export/export_service.dart';

/// Área de relatórios: exportação para Excel do extrato (por ciclo ou por
/// período escolhido) e da ficha dos membros.
class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key, required this.api, this.exporter});

  final ApiClient api;

  /// Substitui o exportador (testes).
  final ExportService? exporter;

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  late final ExportService _export =
      widget.exporter ?? ExportService(widget.api);
  late final Future<List<CycleInfo>> _cycles = DashboardService(
    widget.api,
  ).load().then((data) => data.cycles);
  bool _byPeriod = false;
  String? _cycleId;
  DateTimeRange? _period;
  String? _busy;

  Future<void> _pickPeriod() async {
    final today = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: today.add(const Duration(days: 365)),
      initialDateRange:
          _period ??
          DateTimeRange(
            start: DateTime(today.year, today.month, 1),
            end: today,
          ),
      helpText: 'Período do extrato',
    );
    if (picked != null) setState(() => _period = picked);
  }

  Future<void> _run(String label, Future<void> Function() action) async {
    setState(() => _busy = label);
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeApiError(error))));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _exportStatement() async {
    if (_byPeriod && _period == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escolha o período do extrato.')),
      );
      return;
    }
    await _run(
      'extrato',
      () => _export.exportStatement(
        cycleId: _byPeriod ? null : _cycleId,
        period: _byPeriod ? _period : null,
      ),
    );
  }

  Future<void> _exportMembers() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exportar membros?'),
        content: const Text(
          'A planilha contém dados pessoais (CPF, RG, endereço, telefone). '
          'Compartilhe somente com quem precisa e não deixe o arquivo em '
          'grupos ou locais públicos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Exportar'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _run('membros', _export.exportMembers);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Relatórios')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            title: 'Extrato da tesouraria (Excel)',
            icon: Icons.table_view_outlined,
            children: [
              const Text(
                'Resumo, ofertas de culto, dízimos, ofertas alçadas, despesas '
                'e contas a pagar, em abas separadas.',
              ),
              const SizedBox(height: 12),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    icon: Icon(Icons.date_range),
                    label: Text('Ciclo'),
                  ),
                  ButtonSegment(
                    value: true,
                    icon: Icon(Icons.edit_calendar),
                    label: Text('Período'),
                  ),
                ],
                selected: {_byPeriod},
                onSelectionChanged: (value) =>
                    setState(() => _byPeriod = value.first),
              ),
              const SizedBox(height: 12),
              if (_byPeriod)
                OutlinedButton.icon(
                  onPressed: _pickPeriod,
                  icon: const Icon(Icons.calendar_month),
                  label: Text(
                    _period == null
                        ? 'Escolher datas'
                        : '${formatDate(_period!.start)} a '
                              '${formatDate(_period!.end)}',
                  ),
                )
              else
                FutureBuilder<List<CycleInfo>>(
                  future: _cycles,
                  builder: (context, snapshot) {
                    final cycles = snapshot.data ?? const <CycleInfo>[];
                    if (cycles.isEmpty) {
                      return const Text('Ciclo atual.');
                    }
                    final selected =
                        _cycleId ??
                        cycles
                            .firstWhere(
                              (cycle) => cycle.isOpen,
                              orElse: () => cycles.first,
                            )
                            .id;
                    return CycleSelector(
                      cycles: cycles,
                      selectedId: selected,
                      onChanged: (id) => setState(() => _cycleId = id),
                    );
                  },
                ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _busy == null ? _exportStatement : null,
                icon: _busy == 'extrato'
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download),
                label: const Text('Gerar Excel do extrato'),
              ),
            ],
          ),
          SectionCard(
            title: 'Membros (Excel)',
            icon: Icons.groups_outlined,
            children: [
              const Text(
                'Ficha completa de todos os membros, nas colunas da planilha '
                'de membros.',
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _busy == null ? _exportMembers : null,
                icon: _busy == 'membros'
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download),
                label: const Text('Gerar Excel dos membros'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
