import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:signals/signals_flutter.dart';

import '../../../core/shared/widgets/custom_button_default_widget.dart';
import '../../../core/shared/widgets/month_field_widget.dart';
import '../../../core/utils/amount_version_utils.dart';
import '../../../core/utils/month_utils.dart';
import '../../../data/models/expense_model.dart';
import '../controller/expense_controller.dart';

/// Encerramento: o gasto existiu e parou — cancelei o serviço, mudei de casa.
/// Diferente de excluir, que apaga o histórico como se nunca tivesse existido
/// (GFX-08).
///
/// Quem o fecha no sucesso é o controller; na falha ele fica aberto, e o
/// recado sai por toast.
Future<void> showExpenseClosureDialog(
  BuildContext context, {
  required ExpenseController controller,
  required ExpenseModel expense,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) =>
        _ExpenseClosureDialog(controller: controller, expense: expense),
  );
}

class _ExpenseClosureDialog extends StatefulWidget {
  const _ExpenseClosureDialog({
    required this.controller,
    required this.expense,
  });

  final ExpenseController controller;
  final ExpenseModel expense;

  @override
  State<_ExpenseClosureDialog> createState() => _ExpenseClosureDialogState();
}

class _ExpenseClosureDialogState extends State<_ExpenseClosureDialog> {
  static const _lastMonth = 'lastMonth';

  late final FormGroup _form = FormGroup({
    _lastMonth: FormControl<String>(
      value: _initialMonth,
      validators: [Validators.required],
    ),
  });

  /// O último mês não pode ser anterior ao início da vigência atual. Diferente
  /// do reajuste, aqui o próprio mês de início é permitido.
  String? get _minMonth =>
      AmountVersionUtils.openVersion(widget.expense.history)?.validFrom;

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
      widget.expense.id,
      lastMonth: _form.control(_lastMonth).value as String,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('Encerrar gasto'),
        content: ReactiveForm(
          formGroup: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Escolha o último mês em que você pagou. O histórico continua, e '
                'os meses anteriores seguem contando no resumo.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              MonthFieldWidget(
                formControlName: _lastMonth,
                label: 'Último mês pago',
              ),
            ],
          ),
        ),
        actions: [
          SignalBuilder(
            builder: (context) => TextButton(
              onPressed: widget.controller.saving.value
                  ? null
                  : () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
          ),
          SignalBuilder(
            builder: (context) => CustomButtonDefaultWidget(
              isLoading: widget.controller.saving.value,
              onPressed: _send,
              title: 'Encerrar',
            ),
          ),
        ],
      ),
    );
  }
}
