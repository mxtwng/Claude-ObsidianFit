/// Bottom-navigation shell: Calendar and History tabs, a global "Start
/// workout" button on History, and a re-index whenever the app resumes
/// (directory watching can miss changes made by Syncthing/rsync).
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/vault_reindexer_service.dart';
import '../app_services.dart';
import '../calendar/calendar_page.dart';
import '../history/history_page.dart';
import '../workout/workout_session_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
    return Scaffold(
      // IndexedStack keeps each tab's state (month, filter, scroll) alive.
      body: IndexedStack(
        index: _index,
        children: const [CalendarPage(), HistoryPage()],
      ),
      floatingActionButton: _index == 1
          ? FloatingActionButton.extended(
              onPressed: () => startWorkoutSession(context),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start workout'),
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
        ],
      ),
    );
  }
}
