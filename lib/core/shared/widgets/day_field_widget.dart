import 'package:flutter/material.dart';

class DayFieldWidget extends StatelessWidget {
  final int day;
  final ValueChanged<int> onChanged;
  final String label;
  final String? helperText;

  const DayFieldWidget({
    required this.day,
    required this.onChanged,
    required this.label,
    this.helperText,
    super.key,
  });

  static const _first = 1;
  static const _last = 31;

  int _previous(int day) => day <= _first ? _last : day - 1;
  int _next(int day) => day >= _last ? _first : day + 1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final input = theme.inputDecorationTheme;
    final border = input.border;
    final supportingStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Column(
      crossAxisAlignment: .start,
      spacing: 5,
      children: [
        Padding(
          padding: const .only(left: 8),
          child: Text(label, style: supportingStyle),
        ),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            border: Border.fromBorderSide(
              BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            borderRadius: border is OutlineInputBorder
                ? border.borderRadius
                : BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Dia anterior',
                icon: const Icon(Icons.chevron_left),
                onPressed: () => onChanged(_previous(day)),
              ),
              Expanded(
                child: Text(
                  'Dia $day',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'Próximo dia',
                icon: const Icon(Icons.chevron_right),
                onPressed: () => onChanged(_next(day)),
              ),
            ],
          ),
        ),
        Visibility(
          visible: helperText != null,
          child: Padding(
            padding: const .only(left: 8),
            child: Text(helperText ?? '', style: supportingStyle),
          ),
        ),
      ],
    );
  }
}
