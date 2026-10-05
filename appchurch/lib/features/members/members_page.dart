import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/utils/formatters.dart';
import '../../shared/widgets/async_states.dart';
import 'member.dart';
import 'member_form_page.dart';
import 'members_service.dart';

/// Lista de membros com busca, filtro por função e cadastro.
class MembersPage extends StatefulWidget {
  const MembersPage({
    super.key,
    required this.api,
    this.requiredFields = const {'fullName'},
  });

  final ApiClient api;

  /// Campos obrigatórios do cadastro (configurados na Administração).
  final Set<String> requiredFields;

  @override
  State<MembersPage> createState() => _MembersPageState();
}

class _MembersPageState extends State<MembersPage> {
  late final MembersService _service = MembersService(widget.api);
  late Future<List<Member>> _members;
  String _search = '';
  String? _role;

  @override
  void initState() {
    super.initState();
    _members = _service.list();
  }

  Future<void> _reload() async {
    final future = _service.list();
    setState(() {
      _members = future;
    });
    await future.then((_) {}, onError: (_) {});
  }

  /// Abre o formulário para cadastrar ou, com [member], editar a ficha.
  Future<void> _openForm([Member? member]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MemberFormPage(
          service: _service,
          requiredFields: widget.requiredFields,
          editing: member,
        ),
      ),
    );
    if (saved == true) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Membros')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Novo membro'),
      ),
      body: FutureBuilder<List<Member>>(
        future: _members,
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
          final members = snapshot.data ?? [];
          final roles =
              members
                  .map((member) => member.ministryRole)
                  .whereType<String>()
                  .toSet()
                  .toList()
                ..sort();
          final filtered = members
              .where((member) => member.matches(_search))
              .where((member) => _role == null || member.ministryRole == _role)
              .toList();
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Buscar por nome, função, telefone ou e-mail',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => setState(() => _search = value),
                ),
                if (roles.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      ChoiceChip(
                        label: const Text('Todos'),
                        selected: _role == null,
                        onSelected: (_) => setState(() => _role = null),
                      ),
                      for (final role in roles)
                        ChoiceChip(
                          label: Text(role),
                          selected: _role == role,
                          onSelected: (_) => setState(() => _role = role),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  '${filtered.length} de ${members.length} membro(s)',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                if (filtered.isEmpty)
                  const EmptyMessage(
                    icon: Icons.person_search,
                    message: 'Nenhum membro encontrado.',
                  )
                else
                  for (final member in filtered)
                    _MemberTile(member: member, onEdit: _openForm),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member, required this.onEdit});

  final Member member;
  final ValueChanged<Member> onEdit;

  @override
  Widget build(BuildContext context) {
    final details = [
      if (member.pendingSync) 'Aguardando sincronização',
      member.ministryRole,
      member.phone,
    ].whereType<String>().join(' • ');
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Text(member.fullName.characters.first.toUpperCase()),
        ),
        title: Text(member.fullName),
        subtitle: details.isEmpty ? null : Text(details),
        trailing: Icon(
          member.pendingSync
              ? Icons.cloud_upload_outlined
              : Icons.chevron_right,
        ),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          builder: (sheetContext) => _MemberDetails(
            member: member,
            onEdit: () {
              Navigator.pop(sheetContext);
              onEdit(member);
            },
          ),
        ),
      ),
    );
  }
}

class _MemberDetails extends StatelessWidget {
  const _MemberDetails({required this.member, required this.onEdit});

  final Member member;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    String? date(DateTime? value) => value == null ? null : formatDate(value);
    final rows = <(IconData, String, String?)>[
      (Icons.badge_outlined, 'Função ministerial', member.ministryRole),
      (Icons.event_outlined, 'Função desde', date(member.ministryRoleSince)),
      (Icons.cake_outlined, 'Nascimento', date(member.birthDate)),
      (Icons.phone_outlined, 'Telefone', member.phone),
      (Icons.email_outlined, 'E-mail', member.email),
      (Icons.home_outlined, 'Endereço', member.address),
      (Icons.favorite_border, 'Estado civil', member.maritalStatus),
      (Icons.person_outline, 'Cônjuge', member.spouseName),
      (Icons.child_care, 'Nº de filhos', member.childrenCount?.toString()),
      (Icons.woman_outlined, 'Filiação: mãe', member.motherName),
      (Icons.man_outlined, 'Filiação: pai', member.fatherName),
      (Icons.flag_outlined, 'Nacionalidade', member.nationality),
      (Icons.location_city_outlined, 'Naturalidade', member.birthplace),
      (Icons.school_outlined, 'Escolaridade', member.education),
      (Icons.credit_card_outlined, 'RG', member.rg),
      (Icons.credit_card_outlined, 'CPF', member.cpf),
      (
        Icons.local_fire_department_outlined,
        'Batizado no Espírito Santo',
        switch (member.holySpiritBaptism) {
          true =>
            member.holySpiritBaptismDate == null
                ? 'Sim'
                : 'Sim, em ${formatDate(member.holySpiritBaptismDate)}',
          false => 'Não',
          null => null,
        },
      ),
    ];
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  member.fullName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Editar'),
              ),
            ],
          ),
          if (member.pendingSync)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('Aguardando sincronização.'),
            ),
          const SizedBox(height: 8),
          for (final (icon, label, value) in rows)
            if (value != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(icon),
                title: Text(value),
                subtitle: Text(label),
              ),
        ],
      ),
    );
  }
}
