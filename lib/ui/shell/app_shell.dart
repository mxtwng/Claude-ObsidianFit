/// Bottom-navigation shell: Calendar, History and Dashboard tabs, a global
/// "Start" button on History (gym workout or outdoor GPS activity), and a
/// re-index whenever the app resumes (directory watching can miss changes made
/// by Syncthing/rsync).
///
/// The shell owns the [VaultStatsController] so History (record badges) and
/// Dashboard (weekly totals, records) share one parse of the vault.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/vault_reindexer_service.dart';
import '../app_services.dart';
import '../calendar/calendar_page.dart';
import '../common/start_session_sheet.dart';
import '../common/vault_stats_controller.dart';
import '../dashboard/dashboard_page.dart';
import '../history/history_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _index = 0;
  VaultStatsController? _stats;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // AppScope is only readable from here on, and the services never change
    // for the life of the app, so the controller is created once.
    _stats ??= VaultStatsController(AppScope.of(context));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stats?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    unawaited(
      AppScope.of(context)
          .reindexer
          .reindex()
          .catchError((Object _) => const ReindexReport()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats!;
    return Scaffold(
      // IndexedStack keeps each tab's state (month, filter, scroll) alive.
      body: IndexedStack(
        index: _index,
        children: [
          const CalendarPage(),
          HistoryPage(statsController: stats),
          DashboardPage(controller: stats),
        ],
      ),
      floatingActionButton: _index == 1
          ? FloatingActionButton.extended(
              onPressed: () => showStartSessionSheet(context),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Calendar',
          ),
          NavigationDestination(
            icon: Icon(Icons.history),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Dashboard',
          ),
        ],
      ),
    );
  }
}
