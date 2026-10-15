import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';

import '../../../core/errors/failure.dart';
import '../../../core/shared/widgets/money_field_widget.dart';
import '../../../core/shared/widgets/month_field_widget.dart';
import '../../../core/utils/amount_version_utils.dart';
import '../../../core/utils/month_utils.dart';
import '../../../data/models/income_model.dart';
import '../controller/income_detail_controller.dart';

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

/// Abre o diálogo e devolve `true` se a operação foi aplicada.
Future<bool> showIncomeAmountDialog(
  BuildContext context, {
  required IncomeDetailController controller,
  required IncomeModel income,
  required IncomeAmountMode mode,
}) async {
  final applied = await showDialog<bool>(
    context: context,
    builder: (context) =>
        _IncomeAmountDialog(controller: controller, income: income, mode: mode),
  );
  return applied ?? false;
}

class _IncomeAmountDialog extends StatefulWidget {
  const _IncomeAmountDialog({
    required this.controller,
    required this.income,
    required this.mode,
  });

  final IncomeDetailController controller;
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

  String? _generalError;
  bool _sending = false;

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

    setState(() {
      _sending = true;
      _generalError = null;
    });

    final cents = _form.control(_amount).value as int;
    final failure = _isAdjust
        ? await widget.controller.adjust(
            amountCents: cents,
            effectiveFrom: _form.control(_effectiveFrom).value as String,
          )
        : await widget.controller.correct(amountCents: cents);

    if (!mounted) return;

    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _sending = false;
      // 400 vem campo a campo e desce para o campo; 422 traz a regra de
      // negócio já em português, e ela não pertence a campo nenhum.
      _generalError = _applyFailure(failure);
    });
  }

  /// Devolve a mensagem que sobra para o rodapé do diálogo, ou null se tudo o
  /// que veio já foi pendurado num campo.
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
          child: Text(_isAdjust ? 'Reajustar' : 'Corrigir'),
        ),
      ],
    );
  }
}
