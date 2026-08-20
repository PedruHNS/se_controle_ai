import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';

import '../../../core/shared/widgets/month_field_widget.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/month.dart';
import '../../../data/models/expense_model.dart';
import '../controller/expense_detail_controller.dart';

/// Quitação: paguei o resto adiantado, some com as parcelas de um mês em
/// diante (GPR-14).
///
/// **O valor pago na antecipação não entra em lugar nenhum** — o sistema
/// projeta o que é devido, não concilia o que foi pago. O diálogo diz isso, em
/// vez de deixar a pessoa descobrir depois que o mês não bateu.
Future<bool> showExpenseSettlementDialog(
  BuildContext context, {
  required ExpenseDetailController controller,
  required ExpenseModel expense,
}) async {
  final applied = await showDialog<bool>(
    context: context,
    builder: (context) =>
        _SettlementDialog(controller: controller, expense: expense),
  );
  return applied ?? false;
}

class _SettlementDialog extends StatefulWidget {
  const _SettlementDialog({required this.controller, required this.expense});

  final ExpenseDetailController controller;
  final ExpenseModel expense;

  @override
  State<_SettlementDialog> createState() => _SettlementDialogState();
}

class _SettlementDialogState extends State<_SettlementDialog> {
  static const _fromMonth = 'fromMonth';

  late final FormGroup _form = FormGroup({
    _fromMonth: FormControl<String>(
      value: _initialMonth,
      validators: [Validators.required],
    ),
  });

  String? _generalError;
  bool _sending = false;

  /// Quitar apagando a primeira parcela seria apagar o gasto inteiro, e para
  /// isso existe o Excluir (GPR-15). Daí o piso ser a **segunda**.
  String? get _minMonth {
    final parcels = widget.expense.installments;
    return parcels.length < 2 ? null : parcels[1].referenceMonth;
  }

  String get _initialMonth {
    final current = Month.current();
    final floor = _minMonth;
    if (floor == null) return current;
    return Month.isAfter(floor, current) ? floor : current;
  }

  /// O que deixa de ser cobrado se quitar a partir de [month].
  int _droppedCents(String month) => widget.expense.installments
      .where((parcel) => Month.compare(parcel.referenceMonth, month) >= 0)
      .fold(0, (total, parcel) => total + parcel.amountCents);

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

    final failure = await widget.controller.settle(
      fromMonth: _form.control(_fromMonth).value as String,
    );

    if (!mounted) return;

    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _sending = false;
      _generalError = failure.message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Quitar parcelamento'),
      content: ReactiveForm(
        formGroup: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'As parcelas do mês escolhido em diante somem, e as anteriores '
              'ficam. O valor que você pagou para quitar não é registrado — se '
              'quiser vê-lo no mês, lance um gasto avulso.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            MonthFieldWidget(
              formControlName: _fromMonth,
              label: 'Quitar a partir de',
              minMonth: _minMonth,
            ),
            ReactiveValueListenableBuilder<String>(
              formControlName: _fromMonth,
              builder: (context, control, child) {
                final dropped = _droppedCents(control.value ?? Month.current());
                if (dropped == 0) return const SizedBox.shrink();

                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Deixa de ser cobrado: ${Money.format(dropped)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              },
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
          child: const Text('Quitar'),
        ),
      ],
    );
  }
}
