import 'package:reactive_forms/reactive_forms.dart';

import '../../utils/money.dart';

/// Ponte entre o `FormControl<int>` em **centavos** e o texto do campo.
///
/// O control guarda centavos porque é o que o backend recebe; o campo guarda
/// texto porque é o que a pessoa digita. Sem essa separação, um dos dois lados
/// acaba carregando `double` — e é aí que `0,145` vira 14 centavos.
///
/// O `reactive_forms` só empurra valor de volta para o campo quando a mudança
/// **não** veio dele (ver `_viewToModelChange` no `ControlValueAccessor`), então
/// digitar não é interrompido por reformatação a cada tecla. Já um
/// `updateValue` feito em código — pré-preencher o diálogo de correção, por
/// exemplo — chega formatado no campo.
class MoneyValueAccessor extends ControlValueAccessor<int, String> {
  @override
  String? modelToViewValue(int? modelValue) =>
      modelValue == null ? '' : Money.format(modelValue, showSymbol: false);

  @override
  int? viewToModelValue(String? viewValue) {
    if (viewValue == null || viewValue.trim().isEmpty) return null;
    return Money.tryParse(viewValue);
  }
}
