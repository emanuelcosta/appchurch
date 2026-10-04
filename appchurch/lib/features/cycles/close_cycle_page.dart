import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/utils/formatters.dart';
import '../../shared/widgets/async_states.dart';
import '../dashboard/dashboard_models.dart';
import '../dashboard/widgets/report_sections.dart';
import 'cycles_service.dart';

/// Fechamento do ciclo aberto: escolhe a data final, confere a prévia e
/// confirma. A API grava saldos e repasses e abre o próximo ciclo.
/// Retorna `true` ao fechar a tela quando o ciclo foi fechado.
class CloseCyclePage extends StatefulWidget {
  const CloseCyclePage({super.key, required this.api, required this.cycle});

  final ApiClient api;
  final CycleInfo cycle;

  @override
  State<CloseCyclePage> createState() => _CloseCyclePageState();
}

class _CloseCyclePageState extends State<CloseCyclePage> {
  late final CyclesService _service = CyclesService(widget.api);
  final _notes = TextEditingController();
  late DateTime _endDate = widget.cycle.endDate ?? DateTime.now();
  late Future<DashboardData> _preview = _load();
  bool _closing = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<DashboardData> _load() => _service.preview(widget.cycle.id, _endDate);

  Future<void> _pickEndDate() async {
    final selected = await showDatePicker(
      context: context,
      firstDate: widget.cycle.startDate ?? DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      initialDate: _endDate,
    );
    if (selected == null) return;
    setState(() {
      _endDate = selected;
      _preview = _load();
    });
  }

  Future<void> _confirmAndClose() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fechar ciclo?'),
        content: Text(
          'O ciclo de ${formatDate(widget.cycle.startDate)} a ${formatDate(_endDate)} '
          'será fechado e não poderá mais ser alterado. '
          'Um novo ciclo começará em ${formatDate(_endDate.add(const Duration(days: 1)))}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Fechar ciclo'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _closing = true);
    try {
      final next = await _service.close(
        widget.cycle.id,
        _endDate,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ciclo fechado. Novo ciclo aberto em ${formatDate(next.startDate)}.',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _closing = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeApiError(error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fechar ciclo')),
      body: FutureBuilder<DashboardData>(
        future: _preview,
        builder: (context, snapshot) {
          final loading = snapshot.connectionState == ConnectionState.waiting;
          final data = snapshot.data;
          final blocked = data?.tithe?.headquartersNegative ?? false;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.date_range),
                  title: Text(
                    '${formatDate(widget.cycle.startDate)} a ${formatDate(_endDate)}',
                  ),
                  subtitle: const Text('Toque para alterar a data final'),
                  trailing: const Icon(Icons.edit_calendar),
                  onTap: _closing ? null : _pickEndDate,
                ),
              ),
              const SizedBox(height: 8),
              if (loading)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (snapshot.hasError)
                ErrorRetry(
                  message: describeApiError(snapshot.error!),
                  onRetry: () => setState(() {
                    _preview = _load();
                  }),
                )
              else ...[
                EntriesSection(data: data!),
                ExpensesSection(data: data),
                BalancesSection(data: data),
                TransfersSection(data: data),
                TextField(
                  controller: _notes,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Observações (opcional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _closing || blocked ? null : _confirmAndClose,
                  icon: const Icon(Icons.lock_outline),
                  label: Text(
                    _closing ? 'Fechando...' : 'Fechar ciclo e abrir o próximo',
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
