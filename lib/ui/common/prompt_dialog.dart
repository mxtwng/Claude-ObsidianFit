library;

import 'package:flutter/material.dart';

import '../../models/ModelUtils.dart';

/// Single-line text prompt. Returns the trimmed text, or null if cancelled
/// or empty. [suggestions] render as tappable chips that fill the field.
Future<String?> promptText(
  BuildContext context, {
  required String title,
  String initial = '',
  String? hint,
  List<String> suggestions = const [],
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _PromptDialog(
      title: title,
      initial: initial,
      hint: hint,
      suggestions: suggestions,
    ),
  );
}

class _PromptDialog extends StatefulWidget {
  const _PromptDialog({
    required this.title,
    required this.initial,
    required this.hint,
    required this.suggestions,
  });

  final String title;
  final String initial;
  final String? hint;
  final List<String> suggestions;

  @override
  State<_PromptDialog> createState() => _PromptDialogState();
}

class _PromptDialogState extends State<_PromptDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    Navigator.of(context).pop(text.isEmpty ? null : text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(hintText: widget.hint),
            onSubmitted: (_) => _submit(),
          ),
          if (widget.suggestions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in widget.suggestions)
                  ActionChip(
                    label: Text(s),
                    onPressed: () => Navigator.of(context).pop(s),
                  ),
              ],
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('OK')),
      ],
    );
  }
}

/// Numeric prompt. Returns the parsed value, or null if cancelled. Input
/// outside `[min, max]` keeps the dialog open with an inline error.
/// With [integer] the keyboard has no decimal key and the result is whole.
Future<double?> promptNumber(
  BuildContext context, {
  required String title,
  required double initial,
  bool integer = false,
  double min = 0,
  double? max,
}) {
  return showDialog<double>(
    context: context,
    builder: (_) => _NumberDialog(
      title: title,
      initial: initial,
      integer: integer,
      min: min,
      max: max,
    ),
  );
}

class _NumberDialog extends StatefulWidget {
  const _NumberDialog({
    required this.title,
    required this.initial,
    required this.integer,
    required this.min,
    required this.max,
  });

  final String title;
  final double initial;
  final bool integer;
  final double min;
  final double? max;

  @override
  State<_NumberDialog> createState() => _NumberDialogState();
}

class _NumberDialogState extends State<_NumberDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.integer
        ? '${widget.initial.round()}'
        : formatDecimal(widget.initial),
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final raw = double.tryParse(_controller.text.trim().replaceAll(',', '.'));
    final v = raw == null ? null : (widget.integer ? raw.roundToDouble() : raw);
    final max = widget.max;
    if (v == null || v < widget.min || (max != null && v > max)) {
      setState(() {
        _error = max == null
            ? 'Enter a number of ${formatDecimal(widget.min)} or more'
            : 'Enter a number from ${formatDecimal(widget.min)} '
                'to ${formatDecimal(max)}';
      });
      return;
    }
    Navigator.of(context).pop(v);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.numberWithOptions(decimal: !widget.integer),
        decoration: InputDecoration(errorText: _error),
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Set')),
      ],
    );
  }
}
