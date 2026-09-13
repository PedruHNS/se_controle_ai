/// Conversão e formatação de dinheiro.
///
/// **Dinheiro no app é sempre `int` em centavos** — é assim que o backend envia
/// e recebe, e é o que evita o erro clássico de `double`: `0.1 + 0.2` não dá
/// `0.3` em ponto flutuante, e centavo somado mil vezes acumula diferença. O
/// `double` só aparece aqui dentro, na hora de imprimir.
///
/// Formatação é feita à mão em vez de via `intl` para não adicionar dependência
/// só por causa disto. Se um dia entrar `intl` (por causa de datas, plural ou
/// outro idioma), este arquivo é o único lugar a trocar.
abstract final class MoneyUtils {
  static const _symbol = r'R$';
  static const _thousandSeparator = '.';
  static const _decimalSeparator = ',';

  /// `180000` → `'R$ 1.800,00'`. Negativo vem com o sinal antes do símbolo:
  /// `-4550` → `'-R$ 45,50'`.
  ///
  /// Com [showSymbol] falso, devolve só o número (`'1.800,00'`) — útil dentro de
  /// campo de texto, onde o símbolo costuma ficar no prefixo do input.
  static String format(int cents, {bool showSymbol = true}) {
    final isNegative = cents < 0;
    final absolute = isNegative ? -cents : cents;

    final wholePart = absolute ~/ 100;
    final centsPart = absolute % 100;

    final digits = _groupThousands(wholePart);
    final number =
        '$digits$_decimalSeparator${centsPart.toString().padLeft(2, '0')}';

    return switch ((isNegative, showSymbol)) {
      (true, true) => '-$_symbol $number',
      (true, false) => '-$number',
      (false, true) => '$_symbol $number',
      (false, false) => number,
    };
  }

  /// Como [format], mas com `+` explícito no positivo — para saldo, onde a
  /// diferença entre sobrar e faltar precisa salta aos olhos.
  static String formatSigned(int cents) {
    if (cents <= 0) return format(cents);
    return '+${format(cents)}';
  }

  /// `180000` → `'1.800'`, descartando os centavos. Para eixo de gráfico e
  /// rótulo curto, onde `,00` é ruído.
  static String formatCompact(int cents, {bool showSymbol = true}) {
    final isNegative = cents < 0;
    final absolute = isNegative ? -cents : cents;
    final digits = _groupThousands(absolute ~/ 100);

    return switch ((isNegative, showSymbol)) {
      (true, true) => '-$_symbol $digits',
      (true, false) => '-$digits',
      (false, true) => '$_symbol $digits',
      (false, false) => digits,
    };
  }

  /// Centavos como `double` em reais: `4550` → `45.5`.
  ///
  /// Use só para exibir ou desenhar gráfico. Nunca para calcular e voltar a
  /// centavos — é aí que a imprecisão do ponto flutuante entra.
  static double toReais(int cents) => cents / 100;

  /// Reais em `double` para centavos: `45.5` → `4550`.
  ///
  /// Arredonda em vez de truncar porque a multiplicação erra por baixo: `8.7 *
  /// 100` dá `869.9999999999999`, e truncar devolveria 869 centavos.
  ///
  /// **Arredondar não elimina o problema, só reduz.** Um valor como `0.145` já
  /// chega aqui como `0.1449999...` — nem existe `0.145` exato em binário — e o
  /// resultado é 14, não 15. Para valor digitado pelo usuário use [tryParse],
  /// que lê os dígitos direto do texto e nunca passa por `double`.
  static int fromReais(double reais) => (reais * 100).round();

  /// Lê o que o usuário digitou e devolve centavos. Devolve `null` quando não
  /// há nenhum dígito — deixa a decisão de "campo obrigatório" para o form.
  ///
  /// Aceita as formas que aparecem na prática:
  /// `'R$ 1.800,00'`, `'1800,50'`, `'1.800'`, `'1800'`, `'-45,50'`.
  ///
  /// A vírgula é o separador decimal; o ponto é separador de milhar e é
  /// descartado. `'1.800'` são mil e oitocentos reais, não um e oitenta.
  static int? tryParse(String input) {
    final isNegative = input.contains('-');
    final cleaned = input.replaceAll(RegExp(r'[^0-9,]'), '');
    if (cleaned.isEmpty) return null;

    final parts = cleaned.split(',');
    final whole = parts.first.isEmpty ? '0' : parts.first;

    // Só a primeira vírgula conta como decimal, e só os dois primeiros dígitos:
    // '10,999' é 10,99 — truncar aqui em vez de arredondar para 11,00 evita
    // criar um centavo que o usuário não digitou.
    final fraction = parts.length > 1
        ? parts[1].padRight(2, '0').substring(0, 2)
        : '00';

    final cents = int.tryParse('$whole$fraction');
    if (cents == null) return null;

    return isNegative ? -cents : cents;
  }

  /// Só os dígitos, agrupados de três em três a partir da direita.
  static String _groupThousands(int value) {
    final digits = value.toString();
    if (digits.length <= 3) return digits;

    final buffer = StringBuffer();
    final firstGroupLength = digits.length % 3;

    if (firstGroupLength > 0) {
      buffer.write(digits.substring(0, firstGroupLength));
    }

    for (var i = firstGroupLength; i < digits.length; i += 3) {
      if (buffer.isNotEmpty) buffer.write(_thousandSeparator);
      buffer.write(digits.substring(i, i + 3));
    }

    return buffer.toString();
  }
}
