import 'dart:async';

import 'package:flutter/material.dart';

import 'services/FilePersistenceService.dart';
import 'services/app_database.dart';
import 'services/vault_reindexer_service.dart';
import 'ui/app_services.dart';
import 'ui/shell/app_shell.dart';
import 'ui/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The vault folder is the source of truth; the Drift database is only a
  // disposable read cache rebuilt from it.
  final vault = await FilePersistenceService.openDefault();
  final database = AppDatabase();
  final reindexer = VaultReindexerService(vault: vault, database: database);
  final services = AppServices(
    database: database,
    vault: vault,
    reindexer: reindexer,
  );

  runApp(ObsidianFitApp(services: services));

  // Initial scan + directory watching. Not awaited so the first frame is not
  // blocked; the UI fills in as Drift streams emit.
  unawaited(reindexer.start().catchError((Object _) => const ReindexReport()));
}

class ObsidianFitApp extends StatelessWidget {
  const ObsidianFitApp({super.key, required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    // AppScope sits above MaterialApp so every pushed route can read it.
    return AppScope(
      services: services,
      child: MaterialApp(
        title: 'ObsidianFit',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        darkTheme: buildAppTheme(),
        themeMode: ThemeMode.dark,
        home: const AppShell(),
      ),
    );
  }
}
