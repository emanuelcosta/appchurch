import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Campo de formulário que pode ser marcado como obrigatório na Administração.
class FormFieldOption {
  const FormFieldOption(this.key, this.label, {this.alwaysRequired = false});

  final String key;
  final String label;

  /// Obrigatório sempre (ex.: nome); não pode ser desmarcado.
  final bool alwaysRequired;
}

/// Formulário com campos configuráveis.
class ConfigurableForm {
  const ConfigurableForm({
    required this.id,
    required this.title,
    required this.fields,
    required this.defaultRequired,
  });

  final String id;
  final String title;
  final List<FormFieldOption> fields;
  final Set<String> defaultRequired;
}

const memberForm = ConfigurableForm(
  id: 'member',
  title: 'Cadastro de membro',
  defaultRequired: {'fullName', 'birthDate', 'phone'},
  fields: [
    FormFieldOption('fullName', 'Nome completo', alwaysRequired: true),
    FormFieldOption('birthDate', 'Data de nascimento'),
    FormFieldOption('maritalStatus', 'Estado civil'),
    FormFieldOption('nationality', 'Nacionalidade'),
    FormFieldOption('birthplace', 'Naturalidade'),
    FormFieldOption('education', 'Escolaridade'),
    FormFieldOption('rg', 'RG'),
    FormFieldOption('cpf', 'CPF'),
    FormFieldOption('motherName', 'Filiação: mãe'),
    FormFieldOption('fatherName', 'Filiação: pai'),
    FormFieldOption('spouseName', 'Cônjuge'),
    FormFieldOption('childrenCount', 'Nº de filhos'),
    FormFieldOption('ministryRole', 'Função ministerial'),
    FormFieldOption('ministryRoleSince', 'Função desde'),
    FormFieldOption('holySpiritBaptism', 'Batizado no Espírito Santo'),
    FormFieldOption('phone', 'Telefone'),
    FormFieldOption('email', 'E-mail'),
    FormFieldOption('address', 'Endereço'),
  ],
);

const configurableForms = [memberForm];

/// Guarda, neste aparelho, quais campos de cada formulário são obrigatórios.
class RequiredFieldsStore {
  RequiredFieldsStore();

  final ValueNotifier<Map<String, Set<String>>> required = ValueNotifier({
    for (final form in configurableForms) form.id: form.defaultRequired,
  });

  static String _key(String formId) => 'required_fields_$formId';

  Set<String> of(ConfigurableForm form) => {
    ...?required.value[form.id],
    for (final field in form.fields)
      if (field.alwaysRequired) field.key,
  };

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      required.value = {
        for (final form in configurableForms)
          form.id:
              prefs.getStringList(_key(form.id))?.toSet() ??
              form.defaultRequired,
      };
    } catch (_) {
      // Sem armazenamento disponível: mantém os obrigatórios padrão.
    }
  }

  Future<void> save(ConfigurableForm form, Set<String> fields) async {
    required.value = {...required.value, form.id: fields};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key(form.id), fields.toList());
  }
}
