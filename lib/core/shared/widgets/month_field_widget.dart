import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';

import '../../../data/services/selected_month_service.dart';
import '../../di/injector.dart';
import '../../utils/month_utils.dart';

class MonthFieldWidget extends StatelessWidget {
  final String formControlName;
  final String label;
  final String? helperText;

  const MonthFieldWidget({
    required this.formControlName,
    required this.label,
    this.helperText,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final supportingStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return ReactiveFormField<String, String>(
      formControlName: formControlName,
      validationMessages: {
        ValidationMessage.required: (_) => 'Informe a competência.',
        'backend': (error) => '$error',
      },
      builder: (field) {
        final month = field.value ?? getIt<SelectedMonthService>().month.value;
        final errorText = field.errorText;

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
                border: .fromBorderSide(
                  BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                borderRadius: .circular(8),
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Mês anterior',
                    icon: const Icon(Icons.chevron_left),
                    onPressed: MonthUtils.hasPrevious(month)
                        ? () => field.didChange(MonthUtils.previous(month))
                        : null,
                  ),
                  Expanded(
                    child: Text(
                      MonthUtils.label(month),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Próximo mês',
                    icon: const Icon(Icons.chevron_right),
                    onPressed: MonthUtils.hasNext(month)
                        ? () => field.didChange(MonthUtils.next(month))
                        : null,
                  ),
                ],
              ),
            ),

            Visibility(
              visible: errorText != null || helperText != null,
              child: Padding(
                padding: const .only(left: 8),
                child: Text(
                  errorText ?? helperText ?? '',
                  style: errorText != null
                      ? supportingStyle?.copyWith(
                          color: theme.colorScheme.error,
                        )
                      : supportingStyle,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
