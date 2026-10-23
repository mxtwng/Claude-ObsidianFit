/// Chronological history of every logged session, grouped by month, with a
/// workout/activity filter. Tapping a row opens the parsed session as a GUI
/// card (never raw Markdown).
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../common/session_entries_builder.dart';
import '../common/session_entry.dart';
import '../common/session_preview_sheet.dart';
import '../common/session_tile.dart';
import '../theme/app_theme.dart';

enum _HistoryFilter { all, workouts, activities }

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  _HistoryFilter _filter = _HistoryFilter.all;

  bool _matches(SessionEntry e) => switch (_filter) {
        _HistoryFilter.all => true,
        _HistoryFilter.workouts => e.kind == SessionKind.workout,
        _HistoryFilter.activities => e.kind == SessionKind.activity,
      };

  void _open(SessionEntry entry) {
    showSessionPreview(
      context,
      [entry],
      heading: DateFormat('EEEE, d MMMM y').format(entry.date),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: SessionEntriesBuilder(
        builder: (context, all) {
          final workouts =
              all.where((e) => e.kind == SessionKind.workout).length;
          final activities = all.length - workouts;
          final visible = all.where(_matches).toList();

          // Flat list of month headers (String) and entries, newest first.
          final items = <Object>[];
          String? currentMonth;
          for (final e in visible) {
            final month = DateFormat('MMMM y').format(e.date);
            if (month != currentMonth) {
              items.add(month);
              currentMonth = month;
            }
            items.add(e);
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    _chip('All', all.length, _HistoryFilter.all),
                    const SizedBox(width: 8),
                    _chip('Workouts', workouts, _HistoryFilter.workouts),
                    const SizedBox(width: 8),
                    _chip('Activities', activities, _HistoryFilter.activities),
                  ],
                ),
              ),
              Expanded(
                child: items.isEmpty
                    ? _EmptyHistory(filtered: all.isNotEmpty)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                        itemCount: items.length,
                        itemBuilder: (context, i) {
                          final item = items[i];
                          if (item is String) {
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(2, 14, 0, 8),
                              child: Text(
                                item,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textDim,
                                ),
                              ),
                            );
                          }
                          final entry = item as SessionEntry;
                          return SessionTile(
                            entry: entry,
                            onTap: () => _open(entry),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _chip(String label, int count, _HistoryFilter value) {
    return ChoiceChip(
      label: Text('$label · $count'),
      selected: _filter == value,
      onSelected: (_) => setState(() => _filter = value),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({required this.filtered});

  /// True when sessions exist but the current filter hides them all.
  final bool filtered;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.history, size: 44, color: AppColors.textDim),
            const SizedBox(height: 12),
            Text(
              filtered
                  ? 'No sessions match this filter.'
                  : 'No sessions yet.\nTap "Start workout" to log your first one.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textDim, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
