import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';

import '../../../core/errors/failure.dart';
import '../../../core/shared/widgets/money_field_widget.dart';
import '../../../core/shared/widgets/month_field_widget.dart';
import '../../../core/utils/money_utils.dart';
import '../../../core/utils/month_utils.dart';
import '../../../data/models/expense_model.dart';
import '../controller/expense_detail_controller.dart';

/// Reparcelamento: refaz o plano de um mês em diante.
///
/// **Os dois números são totais da compra, não o que falta** (GPR-07/GPR-08), e
/// é isso que o texto do diálogo precisa deixar claro: quem digita "12" está
/// dizendo "12 no total", contando as que já foram cobradas, não "mais 12".
Future<bool> showExpenseRescheduleDialog(
  BuildContext context, {
  required ExpenseDetailController controller,
  required ExpenseModel expense,
}) async {
  final applied = await showDialog<bool>(
    context: context,
    builder: (context) =>
        _RescheduleDialog(controller: controller, expense: expense),
  );
  return applied ?? false;
}

class _RescheduleDialog extends StatefulWidget {
  const _RescheduleDialog({required this.controller, required this.expense});

  final ExpenseDetailController controller;
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

  String? _generalError;
  bool _sending = false;

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

    // O backend responde 422 com a conta pronta ("2 parcela(s) já foram
    // cobradas..."), mas a viagem é evitável e o número já está aqui.
    if (count <= kept) {
      setState(
        () => _generalError =
            '$kept parcela(s) já foram cobradas antes de '
            '${MonthUtils.label(fromMonth)}. O novo total precisa ser maior que '
            'isso — para encerrar o parcelamento, use Quitar.',
      );
      return;
    }

    setState(() {
      _sending = true;
      _generalError = null;
    });

    final failure = await widget.controller.reschedule(
      newTotalCents: _form.control(_newTotalCents).value as int,
      newInstallmentsCount: count,
      fromMonth: fromMonth,
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
    if (failure is! ValidationFailure || failure.issues.isEmpty) {
      return failure.message;
    }

    var placed = false;
    for (final issue in failure.issues) {
      if (!_form.contains(issue.path)) continue;
      _form.control(issue.path)
        ..setErrors({'backend': issue.message})
        ..markAsTouched();
      placed = true;
    }

    return placed ? null : failure.message;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
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
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _sending ? null : _send,
          child: const Text('Reparcelar'),
        ),
      ],
    );
  }
}
