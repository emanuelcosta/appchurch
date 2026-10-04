import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/settings/due_alert_settings.dart';

/// Configura com quantos dias de antecedência as contas ficam em destaque.
class DueAlertSettingsPage extends StatefulWidget {
  const DueAlertSettingsPage({super.key, required this.store});

  final DueAlertSettingsStore store;

  @override
  State<DueAlertSettingsPage> createState() => _DueAlertSettingsPageState();
}

class _DueAlertSettingsPageState extends State<DueAlertSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  late final _warning = TextEditingController(
    text: widget.store.settings.value.warningDays.toString(),
  );
  late final _urgent = TextEditingController(
    text: widget.store.settings.value.urgentDays.toString(),
  );

  @override
  void dispose() {
    _warning.dispose();
    _urgent.dispose();
    super.dispose();
  }

  String? _validateDays(String? value) {
    final days = int.tryParse(value ?? '');
    if (days == null || days < 0 || days > 60) return 'Informe de 0 a 60 dias.';
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await widget.store.save(
      DueAlertSettings(
        warningDays: int.parse(_warning.text),
        urgentDays: int.parse(_urgent.text),
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Alertas atualizados.')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final digitsOnly = [FilteringTextInputFormatter.digitsOnly];
    return Scaffold(
      appBar: AppBar(title: const Text('Alertas de vencimento')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Contas a vencer aparecem no topo do dashboard com borda animada '
              'conforme os dias que faltam para o vencimento.',
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _warning,
              keyboardType: TextInputType.number,
              inputFormatters: digitsOnly,
              decoration: const InputDecoration(
                labelText: 'Aviso (borda laranja) a partir de quantos dias',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.circle, color: Color(0xFFF57C00)),
                suffixText: 'dias',
              ),
              validator: _validateDays,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _urgent,
              keyboardType: TextInputType.number,
              inputFormatters: digitsOnly,
              decoration: InputDecoration(
                labelText: 'Urgente (borda vermelha) a partir de quantos dias',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(
                  Icons.circle,
                  color: Theme.of(context).colorScheme.error,
                ),
                suffixText: 'dias',
                helperText: 'Contas vencidas também ficam em vermelho.',
              ),
              validator: (value) {
                final error = _validateDays(value);
                if (error != null) return error;
                final warning = int.tryParse(_warning.text) ?? 0;
                return int.parse(value!) > warning
                    ? 'Deve ser menor ou igual ao prazo de aviso.'
                    : null;
              },
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}
