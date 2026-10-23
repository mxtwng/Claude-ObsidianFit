/// Holds the vault-wide stats (weekly totals and personal records) for the
/// dashboard and the history badges.
///
/// The Drift index has no per-set data, so [VaultStatsLoader] parses the
/// notes directly. This controller runs that load once for every screen that
/// needs it, and reloads (debounced) whenever the index changes, i.e. after a
/// save, a re-index or a Syncthing update.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../services/pr_service.dart';
import '../../services/vault_stats_loader.dart';
import '../app_services.dart';

class VaultStatsController extends ChangeNotifier {
  VaultStatsController(AppServices services)
      : _loader = VaultStatsLoader(services.vault) {
    _subs.addAll([
      services.database
          .watchWorkouts()
          .listen((_) => _schedule(), onError: (Object _) {}),
      services.database
          .watchActivities()
          .listen((_) => _schedule(), onError: (Object _) {}),
    ]);
    _schedule();
  }

  /// Quiet period before reloading, so a re-index that touches many rows
  /// causes one load instead of dozens.
  static const Duration debounce = Duration(milliseconds: 400);

  final VaultStatsLoader _loader;
  final List<StreamSubscription<Object?>> _subs = [];
  Timer? _timer;
  bool _running = false;
  bool _rerun = false;
  bool _disposed = false;

  VaultStats? _stats;
  Object? _error;
  bool _loading = true;
  Map<String, List<PrKind>> _recordsByPath = const {};

  /// Last successful load; null until the first one finishes.
  VaultStats? get stats => _stats;

  /// True until the first load finishes (successfully or not).
  bool get loading => _loading;

  /// Error of the last load, cleared by the next successful one.
  Object? get error => _error;

  /// Records keyed by the vault-relative path of the note that holds them
  /// (the same path as `SessionEntry.filePath`), for history badges.
  Map<String, List<PrKind>> get recordsByPath => _recordsByPath;

  /// Reloads now (pull to refresh). Completes when the load is done.
  Future<void> refresh() {
    _timer?.cancel();
    return _run();
  }

  void _schedule() {
    if (_disposed) return;
    _timer?.cancel();
    _timer = Timer(debounce, () => unawaited(_run()));
  }

  Future<void> _run() async {
    if (_disposed) return;
    if (_running) {
      _rerun = true;
      return;
    }
    _running = true;
    try {
      do {
        _rerun = false;
        try {
          final loaded = await _loader.load();
          if (_disposed) return;
          _stats = loaded;
          _error = null;
          _recordsByPath = _groupByPath(loaded.records);
        } catch (e) {
          if (_disposed) return;
          _error = e;
        }
        _loading = false;
        notifyListeners();
      } while (_rerun && !_disposed);
    } finally {
      _running = false;
    }
  }

  static Map<String, List<PrKind>> _groupByPath(PrSnapshot snapshot) {
    final out = <String, List<PrKind>>{};
    for (final kind in PrKind.values) {
      final record = snapshot[kind];
      if (record == null) continue;
      (out[record.sourcePath] ??= <PrKind>[]).add(kind);
    }
    return out;
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    super.dispose();
  }
}
