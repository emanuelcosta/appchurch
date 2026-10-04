import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../shared/widgets/app_version_text.dart';
import '../../shared/widgets/async_states.dart';
import 'profile_service.dart';

/// Dados do usuário logado, congregação, perfil de acesso e saída.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.api, required this.onSignOut});

  final ApiClient api;
  final Future<void> Function() onSignOut;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final ProfileService _service = ProfileService(widget.api);
  late Future<UserProfile> _profile = _load();

  Future<UserProfile> _load() => _service.load();

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sair do aplicativo?'),
        content: const Text(
          'Você precisará entrar novamente com e-mail e senha.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.onSignOut();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        FutureBuilder<UserProfile>(
          future: _profile,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return ErrorRetry(
                message: describeApiError(snapshot.error!),
                onRetry: () => setState(() {
                  _profile = _load();
                }),
              );
            }
            return _ProfileDetails(profile: snapshot.data!);
          },
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: _confirmSignOut,
          icon: const Icon(Icons.logout),
          label: const Text('Sair'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
        ),
        const AppVersionText(),
      ],
    );
  }
}

class _ProfileDetails extends StatelessWidget {
  const _ProfileDetails({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CircleAvatar(
          radius: 36,
          child: Text(
            profile.fullName.characters.first.toUpperCase(),
            style: theme.textTheme.headlineMedium,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          profile.fullName,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge,
        ),
        if (profile.email != null)
          Text(profile.email!, textAlign: TextAlign.center),
        const SizedBox(height: 20),
        if (profile.memberships.isEmpty)
          const Card(
            child: ListTile(
              leading: Icon(Icons.warning_amber),
              title: Text('Usuário sem congregação vinculada.'),
            ),
          ),
        for (final membership in profile.memberships)
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.church_outlined),
                  title: Text(membership.congregation),
                  subtitle: const Text('Congregação'),
                ),
                ListTile(
                  leading: const Icon(Icons.verified_user_outlined),
                  title: Text(membership.role),
                  subtitle: const Text('Perfil de acesso'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
