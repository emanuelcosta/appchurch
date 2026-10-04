import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/api/api_client.dart';
import '../../core/utils/formatters.dart';
import '../../shared/widgets/date_field.dart';
import 'revenues_service.dart';

/// Descrições usadas na planilha para as ofertas de culto (atalhos).
const cultoDescriptions = [
  'Culto de doutrina',
  'Culto evangelístico',
  'Culto de santa ceia',
  'Culto da família',
  'Culto de missões',
];

/// Lançamento de receita no formato da planilha: fundo, data, descrição
/// (ou nome), valor em PIX e em dinheiro e o tipo cadastrado.
/// Título da tela para cada fundo.
const revenueTitles = {
  'OFERTAS_CULTO': 'Lançar oferta de culto',
  'OFERTAS_ALCADAS': 'Lançar oferta alçada',
  'DIZIMOS': 'Lançar dízimo',
};

/// Receita já lançada, para abrir o formulário em modo de edição.
class RevenueDraft {
  const RevenueDraft({
    required this.id,
    required this.fundCode,
    required this.date,
    required this.description,
    required this.pixAmount,
    required this.cashAmount,
    this.categoryId,
  });

  final String id;
  final String fundCode;
  final DateTime? date;
  final String description;
  final double pixAmount;
  final double cashAmount;
  final String? categoryId;
}

class RevenueFormPage extends StatefulWidget {
  const RevenueFormPage({
    super.key,
    required this.api,
    this.fund = 'OFERTAS_CULTO',
    this.editing,
  });

  final ApiClient api;

  /// Fundo da receita (OFERTAS_CULTO, OFERTAS_ALCADAS ou DIZIMOS).
  final String fund;

  /// Com valor, edita a receita (mesmo id) em vez de lançar uma nova.
  final RevenueDraft? editing;

  @override
  State<RevenueFormPage> createState() => _RevenueFormPageState();
}

class _RevenueFormPageState extends State<RevenueFormPage> {
  late final RevenuesService _service = RevenuesService(widget.api);
  late final Future<List<RevenueCategory>> _categories = _service.categories();
  final _formKey = GlobalKey<FormState>();
  late final _description = TextEditingController(
    text: widget.editing?.description,
  );
  late final _pix = TextEditingController(
    text: _initial(widget.editing?.pixAmount),
  );
  late final _cash = TextEditingController(
    text: _initial(widget.editing?.cashAmount),
  );
  final _descriptionFocus = FocusNode();
  late String? _categoryId = widget.editing?.categoryId;
  late DateTime? _date = widget.editing?.date ?? DateTime.now();

  static String? _initial(double? value) =>
      value == null || value == 0 ? null : formatMoneyInput(value);

  bool get _isEditing => widget.editing != null;
  bool _saving = false;
  int _savedCount = 0;
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;

  @override
  void dispose() {
    _description.dispose();
    _pix.dispose();
    _cash.dispose();
    _descriptionFocus.dispose();
    super.dispose();
  }

  String get _fund => widget.editing?.fundCode ?? widget.fund;

  bool get _isOffer => _fund == 'OFERTAS_CULTO';

  double get _total =>
      (parseMoney(_pix.text) ?? 0) + (parseMoney(_cash.text) ?? 0);

  Future<void> _save({required bool another}) async {
    final valid = _formKey.currentState!.validate();
    if (!valid || _total <= 0) {
      setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            !valid
                ? 'Preencha os campos obrigatórios marcados em vermelho.'
                : 'Informe o valor recebido em PIX e/ou dinheiro.',
          ),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final result = await _service.create({
        'id': widget.editing?.id ?? const Uuid().v4(),
        'fundCode': _fund,
        'categoryId': ?_categoryId,
        'date': toIsoDate(_date!),
        'description': _description.text.trim(),
        'pixAmount': parseMoney(_pix.text) ?? 0,
        'cashAmount': parseMoney(_cash.text) ?? 0,
      });
      if (!mounted) return;
      _savedCount++;
      final message = result == SendResult.sent
          ? (_isEditing
                ? 'Receita atualizada.'
                : 'Receita de ${formatMoney(_total)} lançada.')
          : 'Sem conexão: receita salva no aparelho e será enviada quando a conexão voltar.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      if (!another) {
        Navigator.of(context).pop(true);
        return;
      }
      // Mantém fundo, tipo e data; limpa o resto para o próximo lançamento.
      setState(() {
        _saving = false;
        _autovalidate = AutovalidateMode.disabled;
        _description.clear();
        _pix.clear();
        _cash.clear();
      });
      _descriptionFocus.requestFocus();
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(describeApiError(error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 12);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing
              ? 'Editar receita'
              : revenueTitles[_fund] ?? 'Lançar receita',
        ),
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: _autovalidate,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            DateField(
              label: 'Data',
              isRequired: true,
              value: _date,
              onChanged: (value) => setState(() => _date = value),
            ),
            gap,
            TextFormField(
              controller: _description,
              focusNode: _descriptionFocus,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: _isOffer
                    ? 'Descrição do culto *'
                    : 'Nome de quem contribuiu *',
                border: const OutlineInputBorder(),
              ),
              validator: (value) =>
                  (value ?? '').trim().isEmpty ? 'Campo obrigatório.' : null,
            ),
            if (_isOffer) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 0,
                children: [
                  for (final text in cultoDescriptions)
                    ActionChip(
                      label: Text(text),
                      onPressed: () => setState(() {
                        _description.text = text;
                      }),
                    ),
                ],
              ),
            ],
            gap,
            FutureBuilder<List<RevenueCategory>>(
              future: _categories,
              builder: (context, snapshot) {
                final options = (snapshot.data ?? [])
                    .where((category) => category.fundCode == _fund)
                    .toList();
                if (options.isEmpty) return const SizedBox.shrink();
                final selected =
                    options.any((option) => option.id == _categoryId)
                    ? _categoryId
                    : options
                          .firstWhere(
                            (option) => option.isDefault,
                            orElse: () => options.first,
                          )
                          .id;
                _categoryId = selected;
                if (options.length < 2) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tipo', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final option in options)
                          ChoiceChip(
                            label: Text(option.name),
                            selected: option.id == selected,
                            onSelected: (_) =>
                                setState(() => _categoryId = option.id),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            Text(
              'Valor recebido',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _AmountField(
                    controller: _pix,
                    label: 'PIX',
                    icon: Icons.qr_code,
                    onChanged: () => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _AmountField(
                    controller: _cash,
                    label: 'Dinheiro',
                    icon: Icons.payments_outlined,
                    onChanged: () => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Card(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: ListTile(
                title: const Text('Total'),
                trailing: Text(
                  formatMoney(_total),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : () => _save(another: false),
              icon: const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Salvando...' : 'Salvar'),
            ),
            if (!_isEditing) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _saving ? null : () => _save(another: true),
                icon: const Icon(Icons.playlist_add),
                label: const Text('Salvar e lançar outra'),
              ),
            ],
            if (_savedCount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  '$_savedCount receita(s) lançada(s) nesta tela.',
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AmountField extends StatelessWidget {
  const _AmountField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => onChanged(),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        prefixText: 'R\$ ',
        hintText: '0,00',
        border: const OutlineInputBorder(),
      ),
    );
  }
}
