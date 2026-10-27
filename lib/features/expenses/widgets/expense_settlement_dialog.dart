import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:signals/signals_flutter.dart';

import '../../../core/shared/widgets/custom_button_default_widget.dart';
import '../../../core/shared/widgets/month_field_widget.dart';
import '../../../core/utils/money_utils.dart';
import '../../../core/utils/month_utils.dart';
import '../../../data/models/expense_model.dart';
import '../controller/expense_controller.dart';

/// Quitação: paguei o resto adiantado, some com as parcelas de um mês em
/// diante (GPR-14).
///
/// **O valor pago na antecipação não entra em lugar nenhum** — o sistema
/// projeta o que é devido, não concilia o que foi pago. O diálogo diz isso, em
/// vez de deixar a pessoa descobrir depois que o mês não bateu.
///
/// Quem o fecha no sucesso é o controller; na falha ele fica aberto, e o
/// recado sai por toast.
Future<void> showExpenseSettlementDialog(
  BuildContext context, {
  required ExpenseController controller,
  required ExpenseModel expense,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) =>
        _SettlementDialog(controller: controller, expense: expense),
  );
}

class _SettlementDialog extends StatefulWidget {
  const _SettlementDialog({required this.controller, required this.expense});

  final ExpenseController controller;
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

  /// Quitar apagando a primeira parcela seria apagar o gasto inteiro, e para
  /// isso existe o Excluir (GPR-15). Daí o piso ser a **segunda**.
  String? get _minMonth {
    final parcels = widget.expense.installments;
    return parcels.length < 2 ? null : parcels[1].referenceMonth;
  }

  String get _initialMonth {
    final current = MonthUtils.current();
    final floor = _minMonth;
    if (floor == null) return current;
    return MonthUtils.isAfter(floor, current) ? floor : current;
  }

  /// O que deixa de ser cobrado se quitar a partir de [month].
  int _droppedCents(String month) => widget.expense.installments
      .where((parcel) => MonthUtils.compare(parcel.referenceMonth, month) >= 0)
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

    await widget.controller.settle(
      widget.expense.id,
      fromMonth: _form.control(_fromMonth).value as String,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      child: AlertDialog(
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
              ),
              ReactiveValueListenableBuilder<String>(
                formControlName: _fromMonth,
                builder: (context, control, child) {
                  final dropped = _droppedCents(
                    control.value ?? MonthUtils.current(),
                  );
                  if (dropped == 0) return const SizedBox.shrink();

                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Deixa de ser cobrado: ${MoneyUtils.format(dropped)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                },
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
              title: 'Quitar',
            ),
          ),
        ],
      ),
    );
  }
}
