import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/local/app_database.dart';
import '../../core/settings/due_alert_settings.dart';
import '../../core/settings/required_fields.dart';
import '../../core/sync/sync_service.dart';
import '../../shared/widgets/connection_banner.dart';
import '../cycle_report/cycle_report_page.dart';
import '../dashboard/dashboard_page.dart';
import '../ledger/ledger_page.dart';
import '../members/birthdays_page.dart';
import '../members/members_page.dart';
import '../profile/profile_page.dart';
import '../profile/profile_service.dart';
import '../settings/categories_page.dart';
import '../settings/due_alert_settings_page.dart';
import '../settings/required_fields_page.dart';
import 'module_menu.dart';

/// Estrutura principal do app logado: abas inferiores e telas de cada módulo.
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.database,
    required this.api,
    required this.onSignOut,
  });

  final AppDatabase database;
  final ApiClient api;
  final Future<void> Function() onSignOut;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _titles = [
    'Minha congregação',
    'Tesouraria',
    'Secretaria',
    'Administração',
    'Perfil',
  ];

  int _index = 0;

  /// Nome da congregação do usuário logado, exibido no título do Início.
  String? _congregationName;
  late final SyncService _sync = SyncService(
    database: widget.database,
    api: widget.api,
  );

  final _alertSettings = DueAlertSettingsStore();
  final _requiredFields = RequiredFieldsStore();

  @override
  void initState() {
    super.initState();
    _sync.start();
    _alertSettings.load();
    _requiredFields.load();
    _loadCongregationName();
  }

  Future<void> _loadCongregationName() async {
    try {
      final profile = await ProfileService(widget.api).load();
      if (mounted) {
        setState(() => _congregationName = profile.congregationName);
      }
    } catch (_) {
      // Sem perfil disponível: mantém o título padrão.
    }
  }

  @override
  void dispose() {
    _sync.dispose();
    super.dispose();
  }

  /// Recria o dashboard ao voltar do relatório (o ciclo pode ter sido fechado).
  Key _dashboardKey = UniqueKey();

  Future<void> _open(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  Future<void> _openCycleReport() async {
    await _open(CycleReportPage(api: widget.api));
    if (mounted) setState(() => _dashboardKey = UniqueKey());
  }

  Widget _body() {
    return switch (_index) {
      0 => DashboardPage(
        key: _dashboardKey,
        api: widget.api,
        alertSettings: _alertSettings.settings,
        onOpenReport: _openCycleReport,
      ),
      1 => LedgerPage(api: widget.api, onOpenReport: _openCycleReport),
      2 => ModuleMenu(
        title: 'Secretaria',
        actions: [
          ModuleAction(
            icon: Icons.groups_outlined,
            title: 'Membros',
            subtitle: 'Consulte, filtre e cadastre membros da congregação.',
            onTap: () => _open(
              MembersPage(
                api: widget.api,
                requiredFields: _requiredFields.of(memberForm),
              ),
            ),
          ),
          ModuleAction(
            icon: Icons.cake_outlined,
            title: 'Aniversariantes',
            subtitle: 'Veja os aniversariantes de cada mês.',
            onTap: () => _open(BirthdaysPage(api: widget.api)),
          ),
          const ModuleAction(
            icon: Icons.description_outlined,
            title: 'Documentos',
            subtitle: 'Emita fichas e certificados personalizados.',
          ),
        ],
      ),
      3 => ModuleMenu(
        title: 'Administração',
        actions: [
          ModuleAction(
            icon: Icons.notifications_active_outlined,
            title: 'Alertas de vencimento',
            subtitle: 'Defina quando as contas ficam em destaque no dashboard.',
            onTap: () => _open(DueAlertSettingsPage(store: _alertSettings)),
          ),
          ModuleAction(
            icon: Icons.label_outline,
            title: 'Tipos e categorias',
            subtitle: 'Tipos de oferta (ex.: bazar) e categorias de despesa.',
            onTap: () => _open(CategoriesPage(api: widget.api)),
          ),
          ModuleAction(
            icon: Icons.rule,
            title: 'Campos obrigatórios',
            subtitle: 'Defina quais campos dos formulários são obrigatórios.',
            onTap: () => _open(RequiredFieldsPage(store: _requiredFields)),
          ),
          const ModuleAction(
            icon: Icons.tune,
            title: 'Configurações da congregação',
            subtitle: 'Configure módulos, categorias e preferências.',
          ),
          const ModuleAction(
            icon: Icons.manage_accounts_outlined,
            title: 'Usuários e permissões',
            subtitle: 'Gerencie acessos e perfis dos usuários.',
          ),
          const ModuleAction(
            icon: Icons.history,
            title: 'Auditoria',
            subtitle: 'Consulte o histórico de alterações do sistema.',
          ),
        ],
      ),
      _ => ProfilePage(api: widget.api, onSignOut: widget.onSignOut),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/logo.jpg', height: 32, width: 32),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _index == 0 ? _congregationName ?? _titles[0] : _titles[_index],
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          ListenableBuilder(
            listenable: Listenable.merge([widget.api.offline, _sync.pending]),
            builder: (context, _) => ConnectionBanner(
              offline: widget.api.offline.value,
              pending: _sync.pending.value,
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            label: 'Início',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            label: 'Tesouraria',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            label: 'Secretaria',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            label: 'Admin',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
