import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:signals/signals_flutter.dart';

import '../../../core/shared/widgets/month_field_widget.dart';
import '../../../core/utils/amount_version_utils.dart';
import '../../../core/utils/month_utils.dart';
import '../../../data/models/income_model.dart';
import '../controller/income_detail_controller.dart';

/// Encerramento: o ganho existiu e parou. Diferente de excluir, que apaga o
/// histórico como se nunca tivesse existido (GAN-07 vs. GAN-09).
///
/// Quem fecha o diálogo no sucesso é o controller; na falha ele fica aberto, e
/// o recado sai por toast.
Future<void> showIncomeClosureDialog(
  BuildContext context, {
  required IncomeDetailController controller,
  required IncomeModel income,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) =>
        _IncomeClosureDialog(controller: controller, income: income),
  );
}

class _IncomeClosureDialog extends StatefulWidget {
  const _IncomeClosureDialog({required this.controller, required this.income});

  final IncomeDetailController controller;
  final IncomeModel income;

  @override
  State<_IncomeClosureDialog> createState() => _IncomeClosureDialogState();
}

class _IncomeClosureDialogState extends State<_IncomeClosureDialog> {
  static const _lastMonth = 'lastMonth';

  late final FormGroup _form = FormGroup({
    _lastMonth: FormControl<String>(
      value: _initialMonth,
      validators: [Validators.required],
    ),
  });

  /// O último mês não pode ser anterior ao início da vigência atual (GAN-07).
  /// Diferente do reajuste, aqui o próprio mês de início é permitido.
  String? get _minMonth =>
      AmountVersionUtils.openVersion(widget.income.history)?.validFrom;

  String get _initialMonth {
    final from = _minMonth;
    if (from == null) return MonthUtils.current();
    return MonthUtils.isAfter(from, MonthUtils.current())
        ? from
        : MonthUtils.current();
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_form.invalid) {
      _form.markAllAsTouched();
      return;
    }

    await widget.controller.close(
      lastMonth: _form.control(_lastMonth).value as String,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Encerrar ganho'),
      content: ReactiveForm(
        formGroup: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Escolha o último mês em que você recebeu. O histórico continua, '
              'e os meses anteriores seguem contando no resumo.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            MonthFieldWidget(
              formControlName: _lastMonth,
              label: 'Último mês recebido',
            ),
          ],
        ),
      ),
      actions: [
        SignalBuilder(
          builder: (context) => TextButton(
            onPressed: widget.controller.working.value
                ? null
                : () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
        ),
        SignalBuilder(
          builder: (context) => FilledButton(
            onPressed: widget.controller.working.value ? null : _send,
            child: const Text('Encerrar'),
          ),
        ),
      ],
    );
  }
}
