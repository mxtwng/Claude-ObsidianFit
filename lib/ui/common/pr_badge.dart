/// Personal-record widgets: [PrBadge] is the full card shown on the dashboard,
/// [PrChip] the small trophy label on a history row that holds a record.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/pr_service.dart';
import '../theme/app_theme.dart';

IconData prIcon(PrKind kind) => switch (kind) {
      PrKind.bench1rm => Icons.fitness_center,
      PrKind.maxPlank => Icons.timer_outlined,
      PrKind.longestRun => Icons.straighten,
      PrKind.fastest5k => Icons.bolt,
    };

Color prColor(PrKind kind) => switch (kind) {
      PrKind.bench1rm => AppColors.accent,
      PrKind.maxPlank => AppColors.drop,
      PrKind.longestRun => AppColors.activity,
      PrKind.fastest5k => AppColors.warmup,
    };

/// A record set within this many days gets a "NEW" tag.
const int kNewRecordDays = 7;

/// One record, or an empty placeholder when [record] is null.
class PrBadge extends StatelessWidget {
  const PrBadge({super.key, required this.kind, this.record, this.now});

  final PrKind kind;
  final PersonalRecord? record;

  /// Clock for the "NEW" tag; defaults to `DateTime.now()`. Injectable for
  /// tests.
  final DateTime? now;

  bool get _isNew {
    final r = record;
    if (r == null) return false;
    final age = (now ?? DateTime.now()).difference(r.date);
    return !age.isNegative && age.inDays <= kNewRecordDays;
  }

  @override
  Widget build(BuildContext context) {
    final r = record;
    final color = prColor(kind);
    final dim = r == null;
    final detail = r == null
        ? 'Not set yet'
        : [
            if (r.detail.isNotEmpty) r.detail,
            DateFormat('d MMM y').format(r.date),
          ].join(' · ');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: dim ? AppColors.outline : color.withAlpha(120),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: (dim ? AppColors.textDim : color).withAlpha(40),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  prIcon(kind),
                  size: 18,
                  color: dim ? AppColors.textDim : color,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  kind.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDim,
                  ),
                ),
              ),
              if (_isNew)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.done,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'NEW',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            r?.display ?? '--',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: dim ? AppColors.textDim : AppColors.text,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            detail,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textDim,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact trophy label, e.g. on the history row of the session that holds
/// the all-time 1RM.
class PrChip extends StatelessWidget {
  const PrChip({super.key, required this.kind});

  final PrKind kind;

  @override
  Widget build(BuildContext context) {
    final color = prColor(kind);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(35),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(110)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emoji_events, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            kind.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
