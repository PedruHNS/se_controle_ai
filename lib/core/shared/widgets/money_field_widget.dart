import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:reactive_forms/reactive_forms.dart';

import '../forms/money_value_accessor.dart';

/// Campo de dinheiro ligado a um `FormControl<int>` em centavos.
///
/// As mensagens de erro vivem aqui e não em cada formulário: "Informe o valor"
/// é a mesma frase em ganho, cartão e gasto. `backend` é a chave que o
/// repositório usa para pendurar o `issues[].path` de um 400 no campo certo.
class MoneyFieldWidget extends StatelessWidget {
  const MoneyFieldWidget({
    required this.formControlName,
    this.label = 'Valor',
    this.autofocus = false,
    this.onSubmitted,
    super.key,
  });

  final String formControlName;
  final String label;
  final bool autofocus;
  final void Function(FormControl<int>)? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return ReactiveTextField<int>(
      formControlName: formControlName,
      valueAccessor: MoneyValueAccessor(),
      autofocus: autofocus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      // Só dígitos, vírgula e ponto: bloqueia sinal e letra na origem, em vez
      // de recusar depois com mensagem de erro.
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
      textInputAction: TextInputAction.done,
      onSubmitted: onSubmitted,
      validationMessages: {
        ValidationMessage.required: (_) => 'Informe o valor.',
        ValidationMessage.min: (_) => 'O valor precisa ser maior que zero.',
        'backend': (error) => '$error',
      },
      decoration: InputDecoration(
        labelText: label,
        prefixText: r'R$ ',
        border: const OutlineInputBorder(),
      ),
    );
  }
}
