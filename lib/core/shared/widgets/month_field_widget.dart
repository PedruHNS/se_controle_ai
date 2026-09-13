import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';

import '../../utils/month_utils.dart';

/// Seletor de competência `YYYY-MM` por setas, ligado a um `FormControl<String>`.
///
/// Digitar mês livre convida a `2026-13`, a `13/2026` e ao 400 do backend. Com
/// setas o valor é sempre válido por construção, e as setas já param nos
/// limites que o backend aceita (2000–2100) — o mesmo comportamento da home.
///
/// É um `ReactiveFormField` e não um `TextField` disfarçado: o control continua
/// guardando a competência, e o widget é só a forma de mexer nela.
class MonthFieldWidget extends StatelessWidget {
  const MonthFieldWidget({
    required this.formControlName,
    required this.label,
    this.helperText,
    this.minMonth,
    super.key,
  });

  final String formControlName;
  final String label;
  final String? helperText;

  /// Piso adicional ao do backend. O reajuste, por exemplo, não pode valer de
  /// um mês anterior ao início da vigência atual (GAN-05) — travar a seta aqui
  /// evita mandar uma requisição que voltaria 422.
  final String? minMonth;

  bool _canGoPrevious(String month) {
    if (!MonthUtils.hasPrevious(month)) return false;
    final floor = minMonth;
    return floor == null || MonthUtils.isAfter(month, floor);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ReactiveFormField<String, String>(
      formControlName: formControlName,
      validationMessages: {
        ValidationMessage.required: (_) => 'Informe a competência.',
        'backend': (error) => '$error',
      },
      builder: (field) {
        final month = field.value ?? MonthUtils.current();

        return InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            errorText: field.errorText,
            helperText: helperText,
            border: const OutlineInputBorder(),
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Mês anterior',
                icon: const Icon(Icons.chevron_left),
                onPressed: _canGoPrevious(month)
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
        );
      },
    );
  }
}
