import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../shared/widgets/async_states.dart';
import '../../shared/widgets/section_card.dart';
import '../dashboard/dashboard_models.dart';
import '../expenses/expense_models.dart';
import '../expenses/expenses_service.dart';
import '../revenues/revenues_service.dart';

/// Administração: tipos de receita (por fundo, ex.: Bazar em ofertas
/// alçadas) e categorias de despesa usados nos lançamentos.
class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key, required this.api});

  final ApiClient api;

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  late Future<(List<RevenueCategory>, List<ExpenseCategory>)> _data = _load();

  Future<(List<RevenueCategory>, List<ExpenseCategory>)> _load() async => (
    await RevenuesService(widget.api).categories(),
    await ExpensesService(widget.api).categories(),
  );

  Future<void> _add({String? fundCode}) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _NameDialog(
        title: fundCode == null
            ? 'Nova categoria de despesa'
            : 'Novo tipo em ${fundNames[fundCode]}',
      ),
    );
    if (name == null || name.trim().isEmpty || !mounted) return;
    try {
      await widget.api.post(
        fundCode == null
            ? 'finance/expense-categories'
            : 'finance/revenue-categories',
        data: {
          'congregationId': widget.api.congregationId,
          'name': name.trim(),
          'fundCode': ?fundCode,
        },
      );
      setState(() {
        _data = _load();
      });
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
      appBar: AppBar(title: const Text('Tipos e categorias')),
      body: FutureBuilder(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: ErrorRetry(
                message: describeApiError(snapshot.error!),
                onRetry: () => setState(() {
                  _data = _load();
                }),
              ),
            );
          }
          final (revenueTypes, expenseCategories) = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final fund in fundNames.keys)
                SectionCard(
                  title: 'Tipos de ${fundNames[fund]!.toLowerCase()}',
                  icon: Icons.label_outline,
                  trailing: IconButton(
                    tooltip: 'Adicionar tipo',
                    icon: const Icon(Icons.add),
                    onPressed: () => _add(fundCode: fund),
                  ),
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final type in revenueTypes.where(
                          (type) => type.fundCode == fund,
                        ))
                          Chip(label: Text(type.name)),
                      ],
                    ),
                  ],
                ),
              SectionCard(
                title: 'Categorias de despesa',
                icon: Icons.category_outlined,
                trailing: IconButton(
                  tooltip: 'Adicionar categoria',
                  icon: const Icon(Icons.add),
                  onPressed: () => _add(),
                ),
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final category in expenseCategories)
                        Chip(label: Text(category.name)),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.title});

  final String title;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _name,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(labelText: 'Nome'),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _name.text),
          child: const Text('Adicionar'),
        ),
      ],
    );
  }
}
