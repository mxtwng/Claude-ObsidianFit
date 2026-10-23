library;

import 'package:flutter/material.dart';

import '../../models/Models.dart';
import '../theme/app_theme.dart';

Color setTypeColor(SetType type) => switch (type) {
      SetType.warmup => AppColors.warmup,
      SetType.normal => AppColors.textDim,
      SetType.drop => AppColors.drop,
      SetType.failure => AppColors.danger,
    };

String setTypeName(SetType type) => switch (type) {
      SetType.warmup => 'Warm-up',
      SetType.normal => 'Normal',
      SetType.drop => 'Drop set',
      SetType.failure => 'Failure',
    };

/// Round badge: the set number for normal sets, the letter (W/D/F) otherwise.
class SetTypeBadge extends StatelessWidget {
  const SetTypeBadge({super.key, required this.type, required this.number});

  final SetType type;
  final int number;

  @override
  Widget build(BuildContext context) {
    final color = setTypeColor(type);
    final label = type == SetType.normal ? '$number' : type.code;
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 14,
        ),
      ),
    );
  }
}
