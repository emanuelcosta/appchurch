import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/utils/formatters.dart';
import '../../shared/widgets/async_states.dart';
import '../../shared/widgets/pending_sync_note.dart';
import '../dashboard/dashboard_models.dart';
import '../dashboard/widgets/cycle_selector.dart';
import '../expenses/expense_form_page.dart';
import '../revenues/revenue_form_page.dart';
import '../../shared/widgets/filter_chips.dart';
import 'ledger_details_page.dart';
import 'ledger_models.dart';
import 'ledger_service.dart';
import 'widgets/ledger_tile.dart';

enum LedgerFilter { all, income, outcome, payable }

/// Tesouraria em uma tela: extrato do ciclo (receitas, despesas e contas a
/// pagar) com filtros, busca, detalhe e o botão "+" para lançar.
class LedgerPage extends StatefulWidget {
  const LedgerPage({
    super.key,
    required this.api,
    required this.onOpenReport,
    this.initialFilter = LedgerFilter.all,
    this.today,
  });

  final ApiClient api;
  final VoidCallback onOpenReport;
  final LedgerFilter initialFilter;
  final DateTime? today;

  @override
  State<LedgerPage> createState() => _LedgerPageState();
}

class _LedgerPageState extends State<LedgerPage> {
  late final LedgerService _service = LedgerService(widget.api);
  late Future<LedgerData> _data = _service.load();
  String? _cycleId;

  /// Período personalizado: quando definido, substitui o ciclo e traz
  /// lançamentos de qualquer ciclo entre as datas.
  DateTimeRange? _period;
  late LedgerFilter _filter = widget.initialFilter;
  String? _tag;
  String _search = '';

  Future<void> _reload() async {
    final future = _service.load(cycleId: _cycleId, period: _period);
    setState(() {
      _data = future;
    });
    await future.then((_) {}, onError: (_) {});
  }

  Future<void> _pickPeriod() async {
    final today = widget.today ?? DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(day.year + 1, 12, 31),
      initialDateRange:
          _period ??
          DateTimeRange(start: DateTime(day.year, day.month - 3, 1), end: day),
      helpText: 'Período do extrato',
      saveText: 'Buscar',
    );
    if (picked == null || !mounted) return;
    _period = picked;
    _tag = null;
    await _reload();
  }

  /// Busca do início do ciclo mais antigo até hoje, mantendo o texto buscado.
  void _searchAllCycles(List<CycleInfo> cycles) {
    final today = widget.today ?? DateTime.now();
    final starts = cycles.map((cycle) => cycle.startDate).nonNulls;
    final first = starts.fold<DateTime>(
      today,
      (earliest, date) => date.isBefore(earliest) ? date : earliest,
    );
    _period = DateTimeRange(
      start: first,
      end: DateTime(today.year, today.month, today.day),
    );
    _tag = null;
    _reload();
  }

  void _clearPeriod() {
    _period = null;
    _tag = null;
    _reload();
  }

  Future<void> _openAndReload(Widget page) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<Object?>(builder: (_) => page));
    if (mounted) await _reload();
  }

  void _newEntry() {
    final error = Theme.of(context).colorScheme.error;
    Widget option(
      BuildContext sheetContext, {
      required IconData icon,
      required Color color,
      required String title,
      required String subtitle,
      required Widget page,
    }) => ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(icon, color: color),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: () {
        Navigator.pop(sheetContext);
        _openAndReload(page);
      },
    );
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            option(
              sheetContext,
              icon: Icons.church,
              color: Colors.green.shade700,
              title: 'Oferta de culto',
              subtitle: 'Ofertas recebidas nos cultos (PIX e dinheiro)',
              page: RevenueFormPage(api: widget.api, fund: 'OFERTAS_CULTO'),
            ),
            option(
              sheetContext,
              icon: Icons.account_balance,
              color: Colors.green.shade700,
              title: 'Oferta alçada',
              subtitle: 'Oferta mensal, bazar e outros tipos cadastrados',
              page: RevenueFormPage(api: widget.api, fund: 'OFERTAS_ALCADAS'),
            ),
            option(
              sheetContext,
              icon: Icons.volunteer_activism,
              color: Colors.green.shade700,
              title: 'Dízimo',
              subtitle: 'Dízimo por contribuinte',
              page: RevenueFormPage(api: widget.api, fund: 'DIZIMOS'),
            ),
            option(
              sheetContext,
              icon: Icons.arrow_upward,
              color: error,
              title: 'Despesa',
              subtitle: 'Paga agora ou conta a pagar',
              page: ExpenseFormPage(api: widget.api),
            ),
          ],
        ),
      ),
    );
  }

  static const _filterLabels = {
    LedgerFilter.all: 'Todos',
    LedgerFilter.income: 'Entradas',
    LedgerFilter.outcome: 'Saídas',
    LedgerFilter.payable: 'A pagar',
  };

  bool get _hasFilters => _filter != LedgerFilter.all || _tag != null;

  /// Movimento (entradas/saídas/a pagar) e tipo ficam num painel para não
  /// poluir o extrato. Trocar o movimento mantém o painel aberto e atualiza
  /// os tipos; escolher um tipo fecha o painel.
  void _openFilters(List<LedgerItem> items) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          void update(VoidCallback change) {
            setState(change);
            setSheetState(() {});
          }

          final textTheme = Theme.of(sheetContext).textTheme;
          final tags =
              items
                  .where(_matchesFilter)
                  .map((item) => item.tag)
                  .toSet()
                  .toList()
                ..sort();
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('Filtros', style: textTheme.titleMedium),
                      ),
                      if (_hasFilters)
                        TextButton(
                          onPressed: () => update(() {
                            _filter = LedgerFilter.all;
                            _tag = null;
                          }),
                          child: const Text('Limpar'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Movimento', style: textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final entry in _filterLabels.entries)
                        ChoiceChip(
                          label: Text(entry.value),
                          selected: _filter == entry.key,
                          onSelected: (_) => update(() {
                            _filter = entry.key;
                            _tag = null;
                          }),
                        ),
                    ],
                  ),
                  if (tags.length >= 2) ...[
                    const SizedBox(height: 16),
                    Text('Tipo', style: textTheme.labelLarge),
                    const SizedBox(height: 8),
                    FilterChips(
                      options: tags,
                      selected: _tag,
                      onSelected: (value) {
                        setState(() => _tag = value);
                        Navigator.pop(sheetContext);
                      },
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  bool _matchesFilter(LedgerItem item) => switch (_filter) {
    LedgerFilter.all => true,
    LedgerFilter.income => item.kind == LedgerKind.revenue,
    LedgerFilter.outcome => item.kind == LedgerKind.expense,
    LedgerFilter.payable => item.kind == LedgerKind.payable,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newEntry,
        icon: const Icon(Icons.add),
        label: const Text('Lançar'),
      ),
      body: FutureBuilder<LedgerData>(
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
          final byKind = data.items.where(_matchesFilter).toList();
          final visible = byKind
              .where((item) => _tag == null || item.tag == _tag)
              .where((item) => item.matches(_search))
              .toList();
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _period != null
                          ? _PeriodBanner(
                              period: _period!,
                              onEdit: _pickPeriod,
                              onClear: _clearPeriod,
                            )
                          : data.cycles.isNotEmpty
                          ? CycleSelector(
                              cycles: data.cycles,
                              selectedId: data.cycle?.id,
                              onChanged: (id) {
                                _cycleId = id;
                                _reload();
                              },
                            )
                          : const SizedBox.shrink(),
                    ),
                    if (_period == null) ...[
                      const SizedBox(width: 8),
                      IconButton.outlined(
                        tooltip: 'Buscar por período',
                        onPressed: _pickPeriod,
                        icon: const Icon(Icons.edit_calendar),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                _CycleTotals(
                  items: data.items,
                  onOpenReport: widget.onOpenReport,
                ),
                PendingSyncNote(api: widget.api, compact: true),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Buscar por descrição, nome, tipo ou valor',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (value) => setState(() => _search = value),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.outlined(
                      tooltip: 'Filtros',
                      isSelected: _hasFilters,
                      onPressed: () => _openFilters(data.items),
                      icon: Badge(
                        isLabelVisible: _hasFilters,
                        smallSize: 8,
                        child: const Icon(Icons.filter_list),
                      ),
                    ),
                  ],
                ),
                if (_hasFilters) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (_filter != LedgerFilter.all)
                        InputChip(
                          label: Text(_filterLabels[_filter]!),
                          deleteButtonTooltipMessage: 'Limpar movimento',
                          onDeleted: () => setState(() {
                            _filter = LedgerFilter.all;
                            _tag = null;
                          }),
                        ),
                      if (_tag != null)
                        InputChip(
                          label: Text(_tag!),
                          deleteButtonTooltipMessage: 'Limpar tipo',
                          onDeleted: () => setState(() => _tag = null),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                if (visible.isEmpty)
                  const EmptyMessage(
                    icon: Icons.inbox,
                    message: 'Nenhum lançamento encontrado.',
                  )
                else
                  ..._groupedTiles(visible),
                if (_search.trim().isNotEmpty &&
                    _period == null &&
                    data.cycles.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Center(
                      child: TextButton.icon(
                        onPressed: () => _searchAllCycles(data.cycles),
                        icon: const Icon(Icons.history),
                        label: const Text('Buscar em todos os ciclos'),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Contas a pagar primeiro (por vencimento); depois os lançamentos
  /// agrupados por dia, do mais recente para o mais antigo.
  List<Widget> _groupedTiles(List<LedgerItem> items) {
    final payables =
        items.where((item) => item.kind == LedgerKind.payable).toList()
          ..sort((a, b) => _compareDates(a.date, b.date));
    final movements =
        items.where((item) => item.kind != LedgerKind.payable).toList()
          ..sort((a, b) => _compareDates(b.date, a.date));
    final widgets = <Widget>[];
    LedgerItem? previous;
    void addTile(LedgerItem item) => widgets.add(
      LedgerTile(
        item: item,
        today: widget.today,
        onTap: () =>
            _openAndReload(LedgerDetailsPage(api: widget.api, item: item)),
      ),
    );
    if (payables.isNotEmpty) {
      widgets.add(_GroupHeader('A pagar (${payables.length})'));
      payables.forEach(addTile);
    }
    for (final item in movements) {
      if (previous == null || !_sameDay(previous.date, item.date)) {
        widgets.add(_GroupHeader(_dayLabel(item.date)));
      }
      addTile(item);
      previous = item;
    }
    return widgets;
  }

  int _compareDates(DateTime? a, DateTime? b) =>
      (a ?? DateTime(1900)).compareTo(b ?? DateTime(1900));

  bool _sameDay(DateTime? a, DateTime? b) =>
      a != null &&
      b != null &&
      a.year == b.year &&
      a.month == b.month &&
      a.day == b.day;

  String _dayLabel(DateTime? date) {
    if (date == null) return 'Sem data';
    final today = widget.today ?? DateTime.now();
    if (_sameDay(date, today)) return 'Hoje';
    if (_sameDay(date, today.subtract(const Duration(days: 1)))) return 'Ontem';
    return formatDate(date);
  }
}

/// Período personalizado em uso, com opções de alterar ou voltar ao ciclo.
class _PeriodBanner extends StatelessWidget {
  const _PeriodBanner({
    required this.period,
    required this.onEdit,
    required this.onClear,
  });

  final DateTimeRange period;
  final VoidCallback onEdit;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Período (todos os ciclos)',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.edit_calendar),
        contentPadding: EdgeInsets.fromLTRB(12, 4, 0, 4),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onEdit,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '${formatDate(period.start)} a ${formatDate(period.end)}',
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Voltar ao ciclo',
            onPressed: onClear,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

/// Totais do ciclo exibido e atalho para o relatório (prestação de contas).
class _CycleTotals extends StatelessWidget {
  const _CycleTotals({required this.items, required this.onOpenReport});

  final List<LedgerItem> items;
  final VoidCallback onOpenReport;

  @override
  Widget build(BuildContext context) {
    double sum(LedgerKind kind) => items
        .where((item) => item.kind == kind && !item.pendingSync)
        .fold(0, (total, item) => total + item.amount);
    final textTheme = Theme.of(context).textTheme;
    Widget total(String label, double value, Color color) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: textTheme.bodySmall),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatMoney(value),
              style: textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            total('Entradas', sum(LedgerKind.revenue), Colors.green.shade700),
            total(
              'Saídas',
              sum(LedgerKind.expense),
              Theme.of(context).colorScheme.error,
            ),
            TextButton.icon(
              onPressed: onOpenReport,
              icon: const Icon(Icons.assessment_outlined),
              label: const Text('Relatório'),
            ),
          ],
        ),
      ),
    );
  }
}
