import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api/api_client.dart';
import '../../core/local/app_database.dart';
import '../home/home_page.dart';
import 'login_page.dart';

/// Decide entre login e app conforme a sessão do Supabase.
/// A sessão fica salva no aparelho, então reiniciar o app (inclusive com
/// hot restart) mantém o usuário logado.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.database, required this.supabase});

  final AppDatabase database;
  final SupabaseClient supabase;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final ApiClient _api = ApiClient(
    accessToken: () async => widget.supabase.auth.currentSession?.accessToken,
    database: widget.database,
  );

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: widget.supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (widget.supabase.auth.currentSession != null) {
          return HomePage(
            database: widget.database,
            api: _api,
            onSignOut: () => widget.supabase.auth.signOut(),
          );
        }
        // Aguarda o primeiro evento de autenticação para não exibir o login
        // enquanto a sessão salva ainda está sendo restaurada.
        if (!snapshot.hasData && !snapshot.hasError) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return LoginPage(supabase: widget.supabase);
      },
    );
  }
}
