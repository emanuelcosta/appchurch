import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/api/api_client.dart';
import '../../core/utils/formatters.dart';
import '../../shared/widgets/pending_sync_note.dart';
import '../../shared/widgets/date_field.dart';
import '../expenses/expense_models.dart';
import '../expenses/expenses_service.dart';
import '../expenses/widgets/funding_split_editor.dart';
import 'ledger_models.dart';
import 'ledger_service.dart';

/// Pagamento de conta a pagar (total ou parcial), com o rateio das fontes.
/// Retorna `true` ao fechar quando o pagamento foi registrado.
class PayPayablePage extends StatefulWidget {
  const PayPayablePage({super.key, required this.api, required this.payable});

  final ApiClient api;
  final LedgerItem payable;

  @override
  State<PayPayablePage> createState() => _PayPayablePageState();
}

class _PayPayablePageState extends State<PayPayablePage> {
  final _formKey = GlobalKey<FormState>();
  late final _amount = TextEditingController(
    text: formatMoneyInput(_remaining),
  );
  final _sources = FundingSplitController();
  Map<String, double>? _available;
  DateTime? _date = DateTime.now();
  String _method = 'PIX';
  bool _saving = false;
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;

  double get _remaining => widget.payable.remaining ?? widget.payable.amount;

  @override
  void initState() {
    super.initState();
    ExpensesService(widget.api)
        .availableBalances()
        .then((value) {
          if (mounted) setState(() => _available = value);
        })
        .catchError((_) {});
  }

  @override
  void dispose() {
    _amount.dispose();
    _sources.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    final total = parseMoney(_amount.text) ?? 0;
    final split = _sources.split(total);
    final valid = _formKey.currentState!.validate();
    if (!valid || split.status != SplitStatus.complete) {
      setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            !valid
                ? 'Revise os campos marcados em vermelho.'
                : split.status == SplitStatus.exceeded
                ? 'As fontes passam ${formatMoney(-split.remaining)} do valor pago.'
                : 'Faltam ${formatMoney(split.remaining)} para completar o valor pago.',
          ),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final result = await LedgerService(widget.api).pay(widget.payable.id, {
        'paymentId': const Uuid().v4(),
        'paymentDate': toIsoDate(_date!),
        'paymentMethod': _method,
        'amount': total,
        'fundingSources': split.nonZeroSources,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result == SendResult.sent
                ? 'Pagamento de ${formatMoney(total)} registrado.'
                : 'Sem conexão: pagamento salvo no aparelho e será enviado quando a conexão voltar.',
          ),
        ),
      );
      Navigator.of(context).pop(true);
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
    final payable = widget.payable;
    final total = parseMoney(_amount.text) ?? 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Pagar conta')),
      body: Form(
        key: _formKey,
        autovalidateMode: _autovalidate,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.receipt_long),
                title: Text(payable.description),
                subtitle: Text(
                  [
                    'Vencimento ${formatDate(payable.date)}',
                    ?payable.category,
                  ].join(' • '),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Em aberto'),
                    Text(
                      formatMoney(_remaining),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Valor pago *',
                prefixText: 'R\$ ',
                helperText: 'Pode ser parcial; o restante continua em aberto.',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final amount = parseMoney(value ?? '');
                if (amount == null || amount <= 0) {
                  return 'Informe o valor pago.';
                }
                if (amount > _remaining + 0.001) {
                  return 'Maior que o valor em aberto (${formatMoney(_remaining)}).';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            DateField(
              label: 'Data do pagamento',
              isRequired: true,
              value: _date,
              onChanged: (value) => setState(() => _date = value),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'PIX', label: Text('PIX')),
                ButtonSegment(value: 'CASH', label: Text('Dinheiro')),
              ],
              selected: {_method},
              onSelectionChanged: (value) =>
                  setState(() => _method = value.first),
            ),
            const SizedBox(height: 20),
            FundingSplitEditor(
              total: total,
              controller: _sources,
              available: _available,
              onChanged: () => setState(() {}),
              availableNote: PendingSyncNote(api: widget.api, compact: true),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : _pay,
              icon: const Icon(Icons.check),
              label: Text(_saving ? 'Registrando...' : 'Registrar pagamento'),
            ),
          ],
        ),
      ),
    );
  }
}
