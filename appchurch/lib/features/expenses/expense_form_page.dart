import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../core/api/api_client.dart';
import '../../core/utils/formatters.dart';
import '../../shared/widgets/date_field.dart';
import 'expense_models.dart';
import 'expenses_service.dart';
import 'widgets/funding_split_editor.dart';

/// Lançamento de despesa no estilo da planilha: informa o valor e combina
/// as fontes de dinheiro, vendo o saldo de cada uma e quanto falta.
/// A API valida de novo (soma das fontes = valor; data em ciclo aberto).
/// Despesa já lançada (paga ou conta a pagar), para editar.
class ExpenseDraft {
  const ExpenseDraft({
    required this.id,
    required this.paid,
    required this.amount,
    required this.description,
    required this.date,
    this.categoryId,
    this.paymentMethod,
    this.fundingSources = const {},
    this.notificationDaysBefore,
  });

  /// Id da conta (`payables`).
  final String id;

  /// `true`: despesa paga (data = pagamento); `false`: conta a pagar.
  final bool paid;
  final double amount;
  final String description;
  final DateTime? date;
  final String? categoryId;
  final String? paymentMethod;
  final Map<String, double> fundingSources;
  final int? notificationDaysBefore;
}

class ExpenseFormPage extends StatefulWidget {
  const ExpenseFormPage({super.key, required this.api, this.editing});

  final ApiClient api;

  /// Com valor, edita a despesa (mesmo id) em vez de lançar uma nova.
  final ExpenseDraft? editing;

  @override
  State<ExpenseFormPage> createState() => _ExpenseFormPageState();
}

class _ExpenseFormPageState extends State<ExpenseFormPage> {
  late final ExpensesService _service = ExpensesService(widget.api);
  final _formKey = GlobalKey<FormState>();
  late final _amount = TextEditingController(
    text: widget.editing == null
        ? null
        : formatMoneyInput(widget.editing!.amount),
  );
  late final _description = TextEditingController(
    text: widget.editing?.description,
  );
  late final _notifyDays = TextEditingController(
    text: '${widget.editing?.notificationDaysBefore ?? 3}',
  );
  late final _sources = FundingSplitController()
    ..fill(widget.editing?.fundingSources ?? const {});
  late final Future<List<ExpenseCategory>> _categories = _service.categories();
  Map<String, double>? _available;
  late String? _categoryId = widget.editing?.categoryId;
  late bool _paidNow = widget.editing?.paid ?? true;
  late DateTime? _paymentDate = widget.editing == null
      ? DateTime.now()
      : widget.editing!.paid
      ? widget.editing!.date
      : DateTime.now();
  late DateTime? _dueDate = widget.editing?.paid == false
      ? widget.editing!.date
      : null;
  late String _paymentMethod = widget.editing?.paymentMethod ?? 'PIX';

  bool get _isEditing => widget.editing != null;
  String? _attachmentName;
  bool _saving = false;
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;

  @override
  void initState() {
    super.initState();
    _service
        .availableBalances()
        .then((value) {
          if (mounted) setState(() => _available = value);
        })
        .catchError((_) {
          // Sem saldos: o rateio continua possível, só sem o "disponível".
        });
  }

  @override
  void dispose() {
    for (final controller in [_amount, _description, _notifyDays]) {
      controller.dispose();
    }
    _sources.dispose();
    super.dispose();
  }

  FundingSplit get _split => _sources.split(parseMoney(_amount.text) ?? 0);

  Future<void> _attach({required bool camera}) async {
    String? name;
    if (camera) {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (photo != null) name = 'Foto do comprovante';
    } else {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      );
      name = result?.files.single.name;
    }
    if (name != null && mounted) setState(() => _attachmentName = name);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    final formValid = _formKey.currentState!.validate();
    final split = _split;
    final splitValid = !_paidNow || split.status == SplitStatus.complete;
    if (!formValid || !splitValid) {
      setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
      _showMessage(
        !formValid
            ? 'Preencha os campos obrigatórios marcados em vermelho.'
            : split.status == SplitStatus.exceeded
            ? 'As fontes passam ${formatMoney(-split.remaining)} do valor da despesa.'
            : 'Faltam ${formatMoney(split.remaining)} para completar o valor da despesa.',
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final result = await _service.create({
        'id': widget.editing?.id ?? const Uuid().v4(),
        'description': _description.text.trim(),
        'categoryId': _categoryId,
        'amount': split.total,
        'status': _paidNow ? 'PAID' : 'PAYABLE',
        if (_paidNow) ...{
          'paymentDate': toIsoDate(_paymentDate!),
          'paymentMethod': _paymentMethod,
          'fundingSources': split.nonZeroSources,
        } else ...{
          'dueDate': toIsoDate(_dueDate!),
          'notificationDaysBefore': int.tryParse(_notifyDays.text) ?? 3,
        },
      });
      if (!mounted) return;
      _showMessage(
        result == SendResult.sent
            ? (_isEditing ? 'Despesa atualizada.' : 'Despesa lançada.')
            : 'Sem conexão: despesa salva no aparelho e será enviada quando a conexão voltar.',
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage(describeApiError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 12);
    final split = _split;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar despesa' : 'Lançar despesa'),
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: _autovalidate,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            TextFormField(
              controller: _amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: Theme.of(context).textTheme.headlineSmall,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Valor da despesa *',
                prefixText: 'R\$ ',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final amount = parseMoney(value ?? '');
                return amount == null || amount <= 0
                    ? 'Informe o valor da despesa.'
                    : null;
              },
            ),
            gap,
            TextFormField(
              controller: _description,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Descrição *',
                hintText: 'Ex.: Aluguel outubro/2026',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  (value ?? '').trim().isEmpty ? 'Campo obrigatório.' : null,
            ),
            gap,
            FutureBuilder<List<ExpenseCategory>>(
              future: _categories,
              builder: (context, snapshot) {
                final categories = snapshot.data ?? [];
                return DropdownButtonFormField<String>(
                  initialValue: _categoryId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Categoria *',
                    border: const OutlineInputBorder(),
                    helperText: snapshot.hasError
                        ? 'Não foi possível carregar as categorias.'
                        : null,
                  ),
                  items: [
                    for (final category in categories)
                      DropdownMenuItem(
                        value: category.id,
                        child: Text(category.name),
                      ),
                  ],
                  onChanged: (value) => setState(() => _categoryId = value),
                  validator: (value) =>
                      value == null ? 'Campo obrigatório.' : null,
                );
              },
            ),
            gap,
            // Na edição o tipo não muda: trocar desfaria o pagamento já feito.
            if (!_isEditing)
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: true,
                    icon: Icon(Icons.payments_outlined),
                    label: Text('Paga agora'),
                  ),
                  ButtonSegment(
                    value: false,
                    icon: Icon(Icons.event_note),
                    label: Text('Conta a pagar'),
                  ),
                ],
                selected: {_paidNow},
                onSelectionChanged: (value) =>
                    setState(() => _paidNow = value.first),
              ),
            gap,
            if (_paidNow) ...[
              DateField(
                label: 'Data do pagamento',
                isRequired: true,
                value: _paymentDate,
                onChanged: (value) => setState(() => _paymentDate = value),
              ),
              gap,
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'PIX', label: Text('PIX')),
                  ButtonSegment(value: 'CASH', label: Text('Dinheiro')),
                ],
                selected: {_paymentMethod},
                onSelectionChanged: (value) =>
                    setState(() => _paymentMethod = value.first),
              ),
              const SizedBox(height: 20),
              FundingSplitEditor(
                total: split.total,
                controller: _sources,
                available: _available,
                onChanged: () => setState(() {}),
              ),
            ] else ...[
              DateField(
                label: 'Vencimento',
                isRequired: true,
                value: _dueDate,
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now().add(const Duration(days: 3650)),
                onChanged: (value) => setState(() => _dueDate = value),
              ),
              gap,
              TextFormField(
                controller: _notifyDays,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Avisar quantos dias antes',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final days = int.tryParse(value ?? '');
                  return days == null || days < 0 || days > 365
                      ? 'Informe de 0 a 365 dias.'
                      : null;
                },
              ),
              const SizedBox(height: 4),
              const Text(
                'As fontes do dinheiro são escolhidas na hora de pagar a conta.',
              ),
            ],
            const SizedBox(height: 20),
            Text('Comprovante', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _attach(camera: true),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Tirar foto'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _attach(camera: false),
                    icon: const Icon(Icons.attach_file),
                    label: const Text('Anexar'),
                  ),
                ),
              ],
            ),
            if (_attachmentName != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.attachment),
                title: Text(_attachmentName!),
                subtitle: const Text(
                  'O envio do comprovante para a nuvem ainda será liberado.',
                ),
                trailing: IconButton(
                  tooltip: 'Remover comprovante',
                  onPressed: () => setState(() => _attachmentName = null),
                  icon: const Icon(Icons.close),
                ),
              ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Salvando...' : 'Salvar despesa'),
            ),
          ],
        ),
      ),
    );
  }
}
