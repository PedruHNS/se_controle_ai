import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';

import '../../../core/errors/failure.dart';
import '../../../core/shared/widgets/month_field_widget.dart';
import '../../../core/utils/month.dart';
import '../../../data/models/expense_model.dart';
import '../controller/expense_detail_controller.dart';

/// Encerramento: o gasto existiu e parou — cancelei o serviço, mudei de casa.
/// Diferente de excluir, que apaga o histórico como se nunca tivesse existido
/// (GFX-08).
Future<bool> showExpenseClosureDialog(
  BuildContext context, {
  required ExpenseDetailController controller,
  required ExpenseModel expense,
}) async {
  final applied = await showDialog<bool>(
    context: context,
    builder: (context) =>
        _ExpenseClosureDialog(controller: controller, expense: expense),
  );
  return applied ?? false;
}

class _ExpenseClosureDialog extends StatefulWidget {
  const _ExpenseClosureDialog({
    required this.controller,
    required this.expense,
  });

  final ExpenseDetailController controller;
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

  String? _generalError;
  bool _sending = false;

  /// O último mês não pode ser anterior ao início da vigência atual. Diferente
  /// do reajuste, aqui o próprio mês de início é permitido.
  String? get _minMonth => widget.expense.currentVersion?.validFrom;

  String get _initialMonth {
    final from = _minMonth;
    if (from == null) return Month.current();
    return Month.isAfter(from, Month.current()) ? from : Month.current();
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

    setState(() {
      _sending = true;
      _generalError = null;
    });

    final failure = await widget.controller.close(
      lastMonth: _form.control(_lastMonth).value as String,
    );

    if (!mounted) return;

    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _sending = false;
      _generalError = _applyFailure(failure);
    });
  }

  String? _applyFailure(Failure failure) {
    if (failure is ValidationFailure && failure.issues.isNotEmpty) {
      for (final issue in failure.issues) {
        if (!_form.contains(issue.path)) continue;
        _form.control(issue.path)
          ..setErrors({'backend': issue.message})
          ..markAsTouched();
        return null;
      }
    }
    return failure.message;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
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
              minMonth: _minMonth,
            ),
            if (_generalError != null) ...[
              const SizedBox(height: 12),
              Text(
                _generalError!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _sending ? null : _send,
          child: const Text('Encerrar'),
        ),
      ],
    );
  }
}
