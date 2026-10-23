/// Rest timer: controller (wall-clock based, so it stays correct if the app
/// is paused) plus the bottom-sheet UI.
library;

import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/Models.dart';
import '../theme/app_theme.dart';

/// Mirrors `rest_timer_defaults_sec` in `schemas/config_schema.json`.
/// TODO: load from the vault config once config parsing exists.
class RestDefaults {
  const RestDefaults._();

  static const int normal = 90;
  static const int heavy = 180;
  static const int warmup = 45;

  /// Heavy = a failure set, or RPE 9+.
  static int forSet(SetType type, double? rpe) {
    if (type == SetType.warmup) return warmup;
    if (type == SetType.failure || (rpe != null && rpe >= 9)) return heavy;
    return normal;
  }
}

class RestTimerController extends ChangeNotifier {
  Timer? _timer;
  DateTime? _endsAt;
  int _totalSec = 0;
  int _remainingSec = 0;
  bool _finished = false;
  bool _disposed = false;

  int get totalSec => _totalSec;
  int get remainingSec => _remainingSec;
  bool get running => _timer != null;
  bool get finished => _finished;

  /// 0..1 elapsed fraction of the current countdown.
  double get progress => _totalSec == 0
      ? 0.0
      : (1 - _remainingSec / _totalSec).clamp(0.0, 1.0).toDouble();

  void start(int seconds) {
    _cancel();
    _finished = false;
    _totalSec = seconds;
    _remainingSec = seconds;
    _endsAt = DateTime.now().add(Duration(seconds: seconds));
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
    _notify();
  }

  /// Adds or removes time. On an idle/finished timer a positive delta starts
  /// a fresh countdown of that length.
  void adjust(int deltaSeconds) {
    final ends = _endsAt;
    if (!running || ends == null) {
      if (deltaSeconds > 0) start(deltaSeconds);
      return;
    }
    _endsAt = ends.add(Duration(seconds: deltaSeconds));
    _tick();
  }

  void skip() {
    _cancel();
    _endsAt = null;
    _remainingSec = 0;
    _finished = false;
    _notify();
  }

  void _tick() {
    final ends = _endsAt;
    if (ends == null) return;
    final ms = ends.difference(DateTime.now()).inMilliseconds;
    final remaining = ms <= 0 ? 0 : (ms / 1000).ceil();
    if (remaining > _totalSec) _totalSec = remaining;
    if (remaining != _remainingSec) {
      _remainingSec = remaining;
      _notify();
    }
    if (remaining == 0) _complete();
  }

  void _complete() {
    _cancel();
    _finished = true;
    _notify();
    unawaited(_buzz());
  }

  Future<void> _buzz() async {
    for (var i = 0; i < 3; i++) {
      if (_disposed) return;
      await HapticFeedback.heavyImpact();
      await Future<void>.delayed(const Duration(milliseconds: 220));
    }
  }

  void _cancel() {
    _timer?.cancel();
    _timer = null;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _cancel();
    super.dispose();
  }
}

String formatClock(int seconds) {
  final m = seconds ~/ 60;
  final s = (seconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

class RestTimerSheet extends StatelessWidget {
  const RestTimerSheet({
    super.key,
    required this.controller,
    required this.onClose,
  });

  final RestTimerController controller;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final finished = controller.finished;
        final active = controller.running;
        final color = finished ? AppColors.done : AppColors.accent;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          decoration: const BoxDecoration(
            color: AppColors.surfaceHigh,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(top: BorderSide(color: AppColors.outline)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text(
                      'Rest timer',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: onClose,
                      icon: const Icon(Icons.keyboard_arrow_down),
                      tooltip: 'Hide',
                    ),
                  ],
                ),
                Text(
                  finished
                      ? 'Go!'
                      : (active
                          ? formatClock(controller.remainingSec)
                          : 'Ready'),
                  style: TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.w800,
                    color: color,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: finished ? 1 : controller.progress,
                    minHeight: 8,
                    color: color,
                    backgroundColor: AppColors.outline,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          controller.adjust(-30);
                        },
                        child: const Text('−30s'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          controller.skip();
                          onClose();
                        },
                        child: const Text('Skip'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          controller.adjust(30);
                        },
                        child: const Text('+30s'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
