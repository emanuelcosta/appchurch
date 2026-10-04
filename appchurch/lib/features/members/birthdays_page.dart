import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/utils/formatters.dart';
import '../../shared/widgets/async_states.dart';
import 'member.dart';
import 'members_service.dart';

/// Aniversariantes do mês escolhido (abre no mês atual).
class BirthdaysPage extends StatefulWidget {
  const BirthdaysPage({super.key, required this.api, this.today});

  final ApiClient api;

  /// Data usada como "hoje"; permite testes determinísticos.
  final DateTime? today;

  @override
  State<BirthdaysPage> createState() => _BirthdaysPageState();
}

class _BirthdaysPageState extends State<BirthdaysPage> {
  late final MembersService _service = MembersService(widget.api);
  late final DateTime _today = widget.today ?? DateTime.now();
  late Future<List<Member>> _members;
  late int _month = _today.month;

  @override
  void initState() {
    super.initState();
    _members = _service.list();
  }

  void _reload() => setState(() {
    _members = _service.list();
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Aniversariantes')),
      body: Column(
        children: [
          SizedBox(
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: 12,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) => ChoiceChip(
                label: Text(monthNames[index]),
                selected: _month == index + 1,
                onSelected: (_) => setState(() => _month = index + 1),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Member>>(
              future: _members,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
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
                final birthdays =
                    (snapshot.data ?? [])
                        .where((member) => member.birthDate?.month == _month)
                        .toList()
                      ..sort(
                        (a, b) => a.birthDate!.day.compareTo(b.birthDate!.day),
                      );
                if (birthdays.isEmpty) {
                  return EmptyMessage(
                    icon: Icons.cake_outlined,
                    message:
                        'Nenhum aniversariante em ${monthNames[_month - 1]}.',
                  );
                }
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final member in birthdays)
                      _BirthdayTile(member: member, today: _today),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BirthdayTile extends StatelessWidget {
  const _BirthdayTile({required this.member, required this.today});

  final Member member;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final birth = member.birthDate!;
    final isToday = birth.month == today.month && birth.day == today.day;
    final age = member.ageInYear(today.year);
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: isToday ? colors.primaryContainer : null,
      child: ListTile(
        leading: CircleAvatar(
          child: Text(birth.day.toString().padLeft(2, '0')),
        ),
        title: Text(member.fullName),
        subtitle: Text(
          [
            if (isToday) 'Hoje!',
            if (age != null) 'Completa $age anos',
            ?member.ministryRole,
          ].join(' • '),
        ),
        trailing: isToday ? const Icon(Icons.celebration) : null,
      ),
    );
  }
}
