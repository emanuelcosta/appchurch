import 'package:flutter/material.dart';

/// Resposta do diálogo de estorno.
typedef ReverseChoice = ({String reason, bool cancelExpense});

/// Pede o motivo do estorno (fica registrado na auditoria). Para pagamento de
/// despesa, pergunta também se a despesa é cancelada ou a conta fica aberta.
Future<ReverseChoice?> showReverseDialog(
  BuildContext context, {
  required String title,
  required String message,
  bool askExpenseOutcome = false,
  bool initialCancelExpense = true,
  String confirmLabel = 'Confirmar estorno',
}) {
  return showDialog<ReverseChoice>(
    context: context,
    builder: (_) => _ReverseDialog(
      title: title,
      message: message,
      askExpenseOutcome: askExpenseOutcome,
      initialCancelExpense: initialCancelExpense,
      confirmLabel: confirmLabel,
    ),
  );
}

class _ReverseDialog extends StatefulWidget {
  const _ReverseDialog({
    required this.title,
    required this.message,
    required this.askExpenseOutcome,
    required this.initialCancelExpense,
    required this.confirmLabel,
  });

  final String title;
  final String message;
  final bool askExpenseOutcome;
  final bool initialCancelExpense;
  final String confirmLabel;

  @override
  State<_ReverseDialog> createState() => _ReverseDialogState();
}

class _ReverseDialogState extends State<_ReverseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reason = TextEditingController();
  late bool _cancelExpense = widget.initialCancelExpense;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _confirm() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop<ReverseChoice>(context, (
      reason: _reason.text.trim(),
      cancelExpense: _cancelExpense,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.message),
              const SizedBox(height: 12),
              TextFormField(
                controller: _reason,
                autofocus: true,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Motivo *',
                  hintText: 'Ex.: valor digitado errado',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => (value ?? '').trim().length < 3
                    ? 'Informe o motivo.'
                    : null,
              ),
              if (widget.askExpenseOutcome) ...[
                const SizedBox(height: 12),
                RadioGroup<bool>(
                  groupValue: _cancelExpense,
                  onChanged: (value) =>
                      setState(() => _cancelExpense = value ?? true),
                  child: const Column(
                    children: [
                      RadioListTile<bool>(
                        contentPadding: EdgeInsets.zero,
                        value: true,
                        title: Text('Cancelar a despesa'),
                        subtitle: Text('A despesa não existe mais.'),
                      ),
                      RadioListTile<bool>(
                        contentPadding: EdgeInsets.zero,
                        value: false,
                        title: Text('Manter a conta em aberto'),
                        subtitle: Text(
                          'O pagamento não aconteceu, mas a conta continua a pagar.',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Voltar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: _confirm,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
