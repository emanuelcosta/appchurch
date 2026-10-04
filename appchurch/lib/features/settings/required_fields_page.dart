import 'package:flutter/material.dart';

import '../../core/settings/required_fields.dart';

/// Administração: escolhe quais campos de cada formulário são obrigatórios.
class RequiredFieldsPage extends StatefulWidget {
  const RequiredFieldsPage({super.key, required this.store});

  final RequiredFieldsStore store;

  @override
  State<RequiredFieldsPage> createState() => _RequiredFieldsPageState();
}

class _RequiredFieldsPageState extends State<RequiredFieldsPage> {
  late final Map<String, Set<String>> _selected = {
    for (final form in configurableForms) form.id: widget.store.of(form),
  };

  Future<void> _save() async {
    for (final form in configurableForms) {
      await widget.store.save(form, _selected[form.id]!);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Campos obrigatórios atualizados.')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Campos obrigatórios')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _save,
        icon: const Icon(Icons.save_outlined),
        label: const Text('Salvar'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          for (final form in configurableForms) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                form.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final field in form.fields)
              SwitchListTile(
                title: Text(field.label),
                subtitle: field.alwaysRequired
                    ? const Text('Sempre obrigatório')
                    : null,
                value: _selected[form.id]!.contains(field.key),
                onChanged: field.alwaysRequired
                    ? null
                    : (value) => setState(() {
                        value
                            ? _selected[form.id]!.add(field.key)
                            : _selected[form.id]!.remove(field.key);
                      }),
              ),
          ],
        ],
      ),
    );
  }
}
