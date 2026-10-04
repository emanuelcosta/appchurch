import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../core/api/api_client.dart';
import '../../core/utils/formatters.dart';
import '../../shared/widgets/date_field.dart';
import 'member.dart';
import 'members_service.dart';

const ministryRoles = [
  'MEMBRO',
  'CONGREGADO',
  'AUXILIAR',
  'DIÁCONO',
  'PRESBÍTERO',
  'EVANGELISTA',
  'PASTOR',
];

const maritalStatuses = [
  'Solteiro(a)',
  'Casado(a)',
  'Divorciado(a)',
  'Viúvo(a)',
  'União estável',
];

const educationLevels = [
  'Fundamental incompleto',
  'Fundamental completo',
  'Médio incompleto',
  'Médio completo',
  'Superior incompleto',
  'Superior completo',
  'Pós-graduação',
];

/// Cadastro de membro com os campos da ficha (planilha membros.xlsx).
/// Retorna `true` ao fechar quando o membro foi salvo ou enfileirado.
class MemberFormPage extends StatefulWidget {
  const MemberFormPage({
    super.key,
    required this.service,
    this.requiredFields = const {'fullName'},
  });

  final MembersService service;

  /// Campos obrigatórios (configuráveis em Administração → Campos obrigatórios).
  final Set<String> requiredFields;

  @override
  State<MemberFormPage> createState() => _MemberFormPageState();
}

class _MemberFormPageState extends State<MemberFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _rg = TextEditingController();
  final _cpf = TextEditingController();
  final _mother = TextEditingController();
  final _father = TextEditingController();
  final _spouse = TextEditingController();
  final _address = TextEditingController();
  final _nationality = TextEditingController(text: 'Brasileira');
  final _birthplace = TextEditingController();
  final _children = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  DateTime? _birthDate;
  DateTime? _roleSince;
  DateTime? _baptismDate;
  String? _role;
  String? _maritalStatus;
  String? _education;
  bool? _baptized;
  bool _saving = false;

  /// Depois da primeira tentativa de salvar, valida enquanto o usuário edita.
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;

  bool _isRequired(String field) => widget.requiredFields.contains(field);

  String _label(String field, String label) =>
      _isRequired(field) ? '$label *' : label;

  String? _requiredCheck(String field, bool empty) =>
      _isRequired(field) && empty ? 'Campo obrigatório.' : null;

  List<TextEditingController> get _controllers => [
    _name,
    _rg,
    _cpf,
    _mother,
    _father,
    _spouse,
    _address,
    _nationality,
    _birthplace,
    _children,
    _phone,
    _email,
  ];

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _text(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  String? _date(DateTime? value) => value == null ? null : toIsoDate(value);

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Preencha os campos obrigatórios marcados em vermelho.',
          ),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final result = await widget.service.create(
        NewMember(
          id: const Uuid().v4(),
          fullName: _name.text.trim(),
          birthDate: _date(_birthDate),
          rg: _text(_rg),
          cpf: _text(_cpf),
          maritalStatus: _maritalStatus,
          motherName: _text(_mother),
          fatherName: _text(_father),
          spouseName: _text(_spouse),
          address: _text(_address),
          nationality: _text(_nationality),
          birthplace: _text(_birthplace),
          ministryRole: _role,
          ministryRoleSince: _date(_roleSince),
          holySpiritBaptism: _baptized,
          holySpiritBaptismDate: _baptized == true ? _date(_baptismDate) : null,
          education: _education,
          childrenCount: int.tryParse(_children.text),
          phone: _text(_phone),
          email: _text(_email),
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result == SendResult.sent
                ? 'Membro cadastrado.'
                : 'Sem conexão: membro salvo no aparelho e será enviado quando a conexão voltar.',
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

  Widget _field(
    String field,
    TextEditingController controller,
    String label, {
    TextInputType? keyboard,
    TextCapitalization capitalization = TextCapitalization.words,
    List<TextInputFormatter>? formatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      textCapitalization: capitalization,
      inputFormatters: formatters,
      validator: (value) =>
          _requiredCheck(field, (value ?? '').trim().isEmpty) ??
          validator?.call(value),
      decoration: InputDecoration(
        labelText: _label(field, label),
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _dropdown(
    String field,
    String label,
    String? value,
    List<String> options,
    ValueChanged<String?> onChanged,
  ) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      validator: (current) => _requiredCheck(field, current == null),
      decoration: InputDecoration(
        labelText: _label(field, label),
        border: const OutlineInputBorder(),
      ),
      items: [
        for (final option in options)
          DropdownMenuItem(value: option, child: Text(option)),
      ],
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    final digits = [FilteringTextInputFormatter.digitsOnly];
    return Scaffold(
      appBar: AppBar(title: const Text('Novo membro')),
      body: Form(
        key: _formKey,
        autovalidateMode: _autovalidate,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const _SectionTitle('Dados pessoais'),
            _field(
              'fullName',
              _name,
              'Nome completo',
              validator: (value) => (value ?? '').trim().length < 3
                  ? 'Informe o nome completo.'
                  : null,
            ),
            DateField(
              label: 'Data de nascimento',
              isRequired: _isRequired('birthDate'),
              value: _birthDate,
              onChanged: (value) => setState(() => _birthDate = value),
            ),
            _dropdown(
              'maritalStatus',
              'Estado civil',
              _maritalStatus,
              maritalStatuses,
              (value) => setState(() => _maritalStatus = value),
            ),
            _field('nationality', _nationality, 'Nacionalidade'),
            _field('birthplace', _birthplace, 'Naturalidade (cidade/UF)'),
            _dropdown(
              'education',
              'Escolaridade',
              _education,
              educationLevels,
              (value) => setState(() => _education = value),
            ),
            const _SectionTitle('Documentos'),
            _field('rg', _rg, 'RG', keyboard: TextInputType.number),
            _field(
              'cpf',
              _cpf,
              'CPF',
              keyboard: TextInputType.number,
              formatters: digits,
              validator: (value) {
                final text = (value ?? '').trim();
                return text.isEmpty || text.length == 11
                    ? null
                    : 'O CPF deve ter 11 números.';
              },
            ),
            const _SectionTitle('Família'),
            _field('motherName', _mother, 'Filiação: mãe'),
            _field('fatherName', _father, 'Filiação: pai'),
            _field('spouseName', _spouse, 'Cônjuge'),
            _field(
              'childrenCount',
              _children,
              'Nº de filhos',
              keyboard: TextInputType.number,
              formatters: digits,
            ),
            const _SectionTitle('Vida ministerial'),
            _dropdown(
              'ministryRole',
              'Função ministerial',
              _role,
              ministryRoles,
              (value) => setState(() => _role = value),
            ),
            DateField(
              label: 'Função desde',
              isRequired: _isRequired('ministryRoleSince'),
              value: _roleSince,
              onChanged: (value) => setState(() => _roleSince = value),
            ),
            _dropdown(
              'holySpiritBaptism',
              'É batizado no Espírito Santo?',
              switch (_baptized) {
                true => 'Sim',
                false => 'Não',
                null => null,
              },
              const ['Sim', 'Não'],
              (value) => setState(() => _baptized = value == 'Sim'),
            ),
            if (_baptized == true)
              DateField(
                label: 'Data do batismo no Espírito Santo',
                value: _baptismDate,
                onChanged: (value) => setState(() => _baptismDate = value),
              ),
            const _SectionTitle('Contato'),
            _field('phone', _phone, 'Telefone', keyboard: TextInputType.phone),
            _field(
              'email',
              _email,
              'E-mail',
              keyboard: TextInputType.emailAddress,
              capitalization: TextCapitalization.none,
              validator: (value) {
                final text = (value ?? '').trim();
                if (text.isEmpty) return null;
                return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)
                    ? null
                    : 'Informe um e-mail válido.';
              },
            ),
            _field(
              'address',
              _address,
              'Endereço',
              capitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Salvando...' : 'Salvar membro'),
            ),
          ].expand((widget) => [widget, const SizedBox(height: 12)]).toList(),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
