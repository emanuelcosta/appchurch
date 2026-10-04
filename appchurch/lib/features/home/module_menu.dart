import 'package:flutter/material.dart';

/// Item de menu de um módulo (Tesouraria, Secretaria, Administração).
/// Sem [onTap], avisa que a funcionalidade ainda será liberada.
class ModuleAction {
  const ModuleAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
}

class ModuleMenu extends StatelessWidget {
  const ModuleMenu({super.key, required this.title, required this.actions});

  final String title;
  final List<ModuleAction> actions;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text('Escolha uma opção para continuar.'),
        const SizedBox(height: 20),
        for (final action in actions) _ModuleActionCard(action: action),
      ],
    );
  }
}

class _ModuleActionCard extends StatelessWidget {
  const _ModuleActionCard({required this.action});

  final ModuleAction action;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(action.icon),
        title: Text(action.title),
        subtitle: Text(action.subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap:
            action.onTap ??
            () => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${action.title} estará disponível em breve.'),
              ),
            ),
      ),
    );
  }
}
