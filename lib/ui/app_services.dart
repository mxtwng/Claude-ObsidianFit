/// App-wide service holder, exposed to the widget tree via [AppScope].
library;

import 'package:flutter/widgets.dart';

import '../services/FilePersistenceService.dart';
import '../services/app_database.dart';
import '../services/vault_reindexer_service.dart';

class AppServices {
  const AppServices({
    required this.database,
    required this.vault,
    required this.reindexer,
  });

  final AppDatabase database;
  final FilePersistenceService vault;
  final VaultReindexerService reindexer;
}

class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.services, required super.child});

  final AppServices services;

  static AppServices of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'No AppScope found above this context.');
    return scope!.services;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => services != oldWidget.services;
}
