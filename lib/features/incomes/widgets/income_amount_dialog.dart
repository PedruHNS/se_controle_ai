import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:signals/signals_flutter.dart';

import '../../../core/shared/widgets/money_field_widget.dart';
import '../../../core/shared/widgets/month_field_widget.dart';
import '../../../core/utils/amount_version_utils.dart';
import '../../../core/utils/month_utils.dart';
import '../../../data/models/income_model.dart';
import '../controller/income_controller.dart';

/// As duas operações de dinheiro do ganho.
///
/// Estão no mesmo diálogo porque a diferença entre elas é **só** o mês de
/// vigência — e é justamente essa diferença que precisa ficar explícita para o
/// usuário, não escondida atrás de um "editar valor".
enum IncomeAmountMode {
  /// Ganhei um aumento: vale de um mês em diante, o passado fica como estava.
  adjust,

  /// Sempre foi outro valor: reescreve a vigência atual, inclusive o passado.
  correct,
}

/// Abre o diálogo. Quem o fecha no sucesso é o controller; na falha ele fica
/// aberto, e o recado sai por toast.
Future<void> showIncomeAmountDialog(
  BuildContext context, {
  required IncomeController controller,
  required IncomeModel income,
  required IncomeAmountMode mode,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) =>
        _IncomeAmountDialog(controller: controller, income: income, mode: mode),
  );
}

class _IncomeAmountDialog extends StatefulWidget {
  const _IncomeAmountDialog({
    required this.controller,
    required this.income,
    required this.mode,
  });

  final IncomeController controller;
  final IncomeModel income;
  final IncomeAmountMode mode;

  @override
  State<_IncomeAmountDialog> createState() => _IncomeAmountDialogState();
}

class _IncomeAmountDialogState extends State<_IncomeAmountDialog> {
  static const _amount = 'amountCents';
  static const _effectiveFrom = 'effectiveFrom';

  late final FormGroup _form = FormGroup({
    _amount: FormControl<int>(
      // Correção parte do valor atual, que é o que se quer ajustar. Reajuste
      // parte vazio: repetir o valor vigente seria recusado com 422 (GAN-04).
      value: _isAdjust ? null : widget.income.amountCents,
      validators: [Validators.required, Validators.min(1)],
    ),
    _effectiveFrom: FormControl<String>(
      value: _firstAllowedMonth,
      validators: [Validators.required],
    ),
  });

  bool get _isAdjust => widget.mode == IncomeAmountMode.adjust;

  /// Reajuste precisa valer de um mês **posterior** ao início da vigência
  /// atual (GAN-03/GAN-05). O diálogo abre nele; abaixo disso o backend
  /// recusa com 422.
  String get _minMonth {
    final from = AmountVersionUtils.openVersion(
      widget.income.history,
    )?.validFrom;
    return from == null ? MonthUtils.current() : MonthUtils.next(from);
  }

  String get _firstAllowedMonth {
    final floor = _minMonth;
    return MonthUtils.isAfter(floor, MonthUtils.current())
        ? floor
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

    final cents = _form.control(_amount).value as int;

    if (_isAdjust) {
      await widget.controller.adjustValueIncome(
        widget.income.id,
        amountCents: cents,
        effectiveFromMonth: _form.control(_effectiveFrom).value as String,
      );
    } else {
      await widget.controller.correctingValueIncome(widget.income.id, amountCents: cents);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(_isAdjust ? 'Reajustar' : 'Corrigir valor'),
      content: ReactiveForm(
        formGroup: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isAdjust
                  ? 'O valor novo passa a valer do mês escolhido em diante. '
                        'Os meses anteriores continuam com o valor antigo.'
                  : 'O valor passa a valer desde o início da vigência atual, '
                        'inclusive nos meses que já passaram.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            MoneyFieldWidget(
              formControlName: _amount,
              autofocus: true,
              label: 'Novo valor',
            ),
            if (_isAdjust) ...[
              const SizedBox(height: 16),
              MonthFieldWidget(
                formControlName: _effectiveFrom,
                label: 'A partir de',
              ),
            ],
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
          builder: (context) => FilledButton(
            onPressed: widget.controller.saving.value ? null : _send,
            child: Text(_isAdjust ? 'Reajustar' : 'Corrigir'),
          ),
        ),
      ],
    );
  }
}
