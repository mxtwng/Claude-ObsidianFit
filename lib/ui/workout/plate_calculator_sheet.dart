library;

import 'package:flutter/material.dart';

import '../../models/Models.dart';
import '../theme/app_theme.dart';
import 'plate_math.dart';

Future<void> showPlateCalculator(BuildContext context,
    {double initialKg = 60}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => PlateCalculatorSheet(initialKg: initialKg),
  );
}

class PlateCalculatorSheet extends StatefulWidget {
  const PlateCalculatorSheet({super.key, required this.initialKg});

  final double initialKg;

  @override
  State<PlateCalculatorSheet> createState() => _PlateCalculatorSheetState();
}

class _PlateCalculatorSheetState extends State<PlateCalculatorSheet> {
  late final TextEditingController _controller =
      TextEditingController(text: formatDecimal(widget.initialKg));
  double _barKg = 20;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static Color _plateColor(double kg) => switch (kg) {
        20.0 => const Color(0xFF3B82F6),
        10.0 => const Color(0xFF22C55E),
        5.0 => const Color(0xFFE5E7EB),
        2.5 => const Color(0xFFF97316),
        _ => const Color(0xFF9CA3AF),
      };

  static double _plateHeight(double kg) => switch (kg) {
        20.0 => 100.0,
        10.0 => 80.0,
        5.0 => 60.0,
        2.5 => 46.0,
        _ => 36.0,
      };

  @override
  Widget build(BuildContext context) {
    final target =
        double.tryParse(_controller.text.trim().replaceAll(',', '.')) ?? 0;
    final result = PlateMath.calculate(target, barKg: _barKg);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Plate calculator',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Target weight',
                      suffixText: 'kg',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                for (final bar in const [20.0, 15.0]) ...[
                  ChoiceChip(
                    label: Text('${formatDecimal(bar)} kg bar'),
                    selected: _barKg == bar,
                    onSelected: (_) => setState(() => _barKg = bar),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
            const SizedBox(height: 20),
            if (result.belowBar)
              Text(
                'Target is lighter than the ${formatDecimal(_barKg)} kg bar.',
                style: const TextStyle(color: AppColors.warmup),
              )
            else ...[
              SizedBox(
                height: 110,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6B7280),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    for (final entry in result.platesPerSide.entries)
                      for (var i = 0; i < entry.value; i++)
                        Container(
                          width: 16,
                          height: _plateHeight(entry.key),
                          margin: const EdgeInsets.only(left: 3),
                          decoration: BoxDecoration(
                            color: _plateColor(entry.key),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (result.platesPerSide.isEmpty)
                const Text(
                  'Just the bar.',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final entry in result.platesPerSide.entries)
                      Chip(
                        avatar: CircleAvatar(
                          backgroundColor: _plateColor(entry.key),
                          radius: 8,
                        ),
                        label: Text(
                          '${formatDecimal(entry.key)} kg × ${entry.value}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: 12),
              Text(
                'Per side: ${formatDecimal(result.perSideKg)} kg  ·  '
                'Loaded: ${formatDecimal(result.loadedKg)} kg',
                style: const TextStyle(color: AppColors.textDim),
              ),
              if (!result.isExact)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Closest loadable weight is '
                    '${formatDecimal(result.loadedKg)} kg '
                    '(${formatDecimal(result.shortfallKg)} kg under target).',
                    style: const TextStyle(color: AppColors.warmup),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
