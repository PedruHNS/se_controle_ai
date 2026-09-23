import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:reactive_forms/reactive_forms.dart';

import '../forms/money_value_accessor.dart';
import 'text_field_custom_widget.dart';

/// Campo de dinheiro ligado a um `FormControl<int>` em centavos.
///
/// É o [TextFieldCustomWidget] com os ajustes de dinheiro já feitos: o
/// acessador que traduz centavos para `8.000,00`, o teclado decimal, o `R$ ` na
/// frente e as mensagens de erro.
///
/// As mensagens vivem aqui e não em cada formulário: "Informe o valor" é a
/// mesma frase em ganho, cartão e gasto. `backend` é a chave que o repositório
/// usa para pendurar o `issues[].path` de um 400 no campo certo.
class MoneyFieldWidget extends StatelessWidget {
  const MoneyFieldWidget({
    required this.formControlName,
    this.label = 'Valor',
    this.autofocus = false,
    super.key,
  });

  final String formControlName;
  final String label;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return TextFieldCustomWidget<int>(
      formControlName: formControlName,
      valueAccessor: MoneyValueAccessor(),
      autofocus: autofocus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      // Só dígitos, vírgula e ponto: bloqueia sinal e letra na origem, em vez
      // de recusar depois com mensagem de erro.
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
      // `done`, e não o `next` do texto comum: o valor costuma ser o último
      // campo que a pessoa toca antes de salvar.
      textInputAction: TextInputAction.done,
      validationMessages: {
        ValidationMessage.required: (_) => 'Informe o valor.',
        ValidationMessage.min: (_) => 'O valor precisa ser maior que zero.',
        'backend': (error) => '$error',
      },
      labelText: label,
      prefixText: r'R$ ',
    );
  }
}
