import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/api/api_client.dart';
import 'core/local/app_database.dart';
import 'features/auth/auth_gate.dart';
import 'features/home/home_page.dart';
import 'supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseAnonKey);
  runApp(
    TesourariaApp(database: AppDatabase(), supabase: Supabase.instance.client),
  );
}

/// Raiz do app. Com [supabase], exige login; sem ele (testes), abre direto
/// a tela principal usando o [api] informado.
class TesourariaApp extends StatelessWidget {
  const TesourariaApp({
    super.key,
    required this.database,
    this.supabase,
    this.api,
  }) : assert(supabase != null || api != null);

  final AppDatabase database;
  final SupabaseClient? supabase;
  final ApiClient? api;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tesouraria',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        scaffoldBackgroundColor: const Color(0xfff7f8fa),
      ),
      home: supabase != null
          ? AuthGate(database: database, supabase: supabase!)
          : HomePage(database: database, api: api!, onSignOut: () async {}),
    );
  }
}
