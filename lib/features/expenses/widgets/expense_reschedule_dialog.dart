import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:signals/signals_flutter.dart';

import '../../../core/shared/widgets/custom_button_default_widget.dart';
import '../../../core/shared/widgets/money_field_widget.dart';
import '../../../core/shared/widgets/month_field_widget.dart';
import '../../../core/utils/money_utils.dart';
import '../../../core/utils/month_utils.dart';
import '../../../data/models/expense_model.dart';
import '../controller/expense_controller.dart';

/// Reparcelamento: refaz o plano de um mês em diante.
///
/// **Os dois números são totais da compra, não o que falta** (GPR-07/GPR-08), e
/// é isso que o texto do diálogo precisa deixar claro: quem digita "12" está
/// dizendo "12 no total", contando as que já foram cobradas, não "mais 12".
///
/// Quem o fecha no sucesso é o controller; na falha ele fica aberto, e o
/// recado sai por toast.
Future<void> showExpenseRescheduleDialog(
  BuildContext context, {
  required ExpenseController controller,
  required ExpenseModel expense,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) =>
        _RescheduleDialog(controller: controller, expense: expense),
  );
}

class _RescheduleDialog extends StatefulWidget {
  const _RescheduleDialog({required this.controller, required this.expense});

  final ExpenseController controller;
  final ExpenseModel expense;

  @override
  State<_RescheduleDialog> createState() => _RescheduleDialogState();
}

class _RescheduleDialogState extends State<_RescheduleDialog> {
  static const _newTotalCents = 'newTotalCents';
  static const _newInstallmentsCount = 'newInstallmentsCount';
  static const _fromMonth = 'fromMonth';

  late final FormGroup _form = FormGroup({
    // Parte do total atual: reparcelar sem mudar o valor, só a quantidade, é
    // caso comum, e obrigar a redigitar o mesmo número seria trabalho à toa.
    _newTotalCents: FormControl<int>(
      value: widget.expense.totalCents,
      validators: [Validators.required, Validators.min(1)],
    ),
    _newInstallmentsCount: FormControl<int>(
      value: widget.expense.installmentsCount,
      validators: [Validators.required],
    ),
    _fromMonth: FormControl<String>(
      value: _initialMonth,
      validators: [Validators.required],
    ),
  });

  /// A recusa que o próprio diálogo dá, antes de ir ao backend.
  String? _countError;

  /// A primeira parcela que ainda não foi cobrada, ou o mês corrente quando
  /// todas já passaram. Reparcelar o passado é permitido (GPR-13), mas não é o
  /// que se quer por padrão.
  String get _initialMonth {
    final current = MonthUtils.current();
    final future = widget.expense.installments
        .map((parcel) => parcel.referenceMonth)
        .where((month) => MonthUtils.compare(month, current) >= 0);
    return future.isEmpty ? current : future.first;
  }

  /// Quantas parcelas ficam de fora do replanejamento — as anteriores ao mês
  /// escolhido, que já foram cobradas.
  int _keptBefore(String month) => widget.expense.installments
      .where((parcel) => MonthUtils.isBefore(parcel.referenceMonth, month))
      .length;

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

    final fromMonth = _form.control(_fromMonth).value as String;
    final count = _form.control(_newInstallmentsCount).value as int;
    final kept = _keptBefore(fromMonth);

    // O backend responde 422 com a mesma conta, mas a viagem é evitável e o
    // número já está aqui.
    if (count <= kept) {
      setState(
        () => _countError =
            '$kept parcela(s) já foram cobradas antes de '
            '${MonthUtils.label(fromMonth)}. O novo total precisa ser maior que '
            'isso — para encerrar o parcelamento, use Quitar.',
      );
      return;
    }

    setState(() => _countError = null);

    await widget.controller.reschedule(
      widget.expense.id,
      newTotalCents: _form.control(_newTotalCents).value as int,
      newInstallmentsCount: count,
      fromMonth: fromMonth,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('Reparcelar'),
        content: ReactiveForm(
          formGroup: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'As parcelas anteriores ao mês escolhido ficam como estão — já '
                  'foram cobradas. O total e a quantidade são da compra inteira, '
                  'contando essas.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                MoneyFieldWidget(
                  formControlName: _newTotalCents,
                  autofocus: true,
                  label: 'Novo total da compra',
                ),
                const SizedBox(height: 16),
                ReactiveTextField<int>(
                  formControlName: _newInstallmentsCount,
                  keyboardType: TextInputType.number,
                  validationMessages: {
                    ValidationMessage.required: (_) =>
                        'Informe a quantidade de parcelas.',
                    ValidationMessage.number: (_) => 'Só números.',
                    'backend': (error) => '$error',
                  },
                  decoration: const InputDecoration(
                    labelText: 'Parcelas no total',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                MonthFieldWidget(
                  formControlName: _fromMonth,
                  label: 'Replanejar a partir de',
                ),
                ReactiveValueListenableBuilder<String>(
                  formControlName: _fromMonth,
                  builder: (context, control, child) {
                    final kept = _keptBefore(
                      control.value ?? MonthUtils.current(),
                    );
                    if (kept == 0) return const SizedBox.shrink();

                    final total = widget.expense.installments
                        .where(
                          (parcel) => MonthUtils.isBefore(
                            parcel.referenceMonth,
                            control.value ?? MonthUtils.current(),
                          ),
                        )
                        .fold(0, (sum, parcel) => sum + parcel.amountCents);

                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '$kept parcela(s) já cobradas, ${MoneyUtils.format(total)} — '
                        'ficam como estão.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  },
                ),
                if (_countError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _countError!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
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
              title: 'Reparcelar',
            ),
          ),
        ],
      ),
    );
  }
}
