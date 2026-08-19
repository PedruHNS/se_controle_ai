import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';

/// Dia do mês, 1 a 31, ligado a um `FormControl<int>`.
///
/// Mesma escolha do `MonthFieldWidget`: seletor, não campo de texto. Digitar dia
/// livre convida ao `0`, ao `45` e ao 400 do backend, cuja mensagem para este
/// caso vem crua do zod ("Too small: expected number to be >=1") — ou seja, uma
/// recusa que o usuário não entenderia. Com o seletor o valor é válido por
/// construção (CAR-02) e a requisição inválida nem sai.
///
/// Trinta e um itens caberiam num `DropdownButton`, mas rolar até o 27 é pior
/// que dois toques na seta quando o valor nasce próximo do desejado. As setas
/// dão a volta: do 31 o "próximo" é o 1.
class DayFieldWidget extends StatelessWidget {
  const DayFieldWidget({
    required this.formControlName,
    required this.label,
    this.helperText,
    super.key,
  });

  final String formControlName;
  final String label;

  /// Onde a explicação do CAR-03 aparece no formulário de cartão: "fecha dia 27
  /// e vence dia 5" precisa dizer que a fatura vence no mês seguinte.
  final String? helperText;

  static const _first = 1;
  static const _last = 31;

  /// Circular de propósito: dia de fechamento e de vencimento ficam muito perto
  /// da virada do mês, e travar no 31 obrigaria 30 toques para voltar ao 1.
  int _previous(int day) => day <= _first ? _last : day - 1;
  int _next(int day) => day >= _last ? _first : day + 1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ReactiveFormField<int, int>(
      formControlName: formControlName,
      validationMessages: {
        ValidationMessage.required: (_) => 'Informe o dia.',
        'backend': (error) => '$error',
      },
      builder: (field) {
        final day = field.value ?? _first;

        return InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            errorText: field.errorText,
            helperText: helperText,
            helperMaxLines: 3,
            border: const OutlineInputBorder(),
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Dia anterior',
                icon: const Icon(Icons.chevron_left),
                onPressed: () => field.didChange(_previous(day)),
              ),
              Expanded(
                child: Text(
                  'Dia $day',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'Próximo dia',
                icon: const Icon(Icons.chevron_right),
                onPressed: () => field.didChange(_next(day)),
              ),
            ],
          ),
        );
      },
    );
  }
}
