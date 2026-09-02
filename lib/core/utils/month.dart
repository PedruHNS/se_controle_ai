/// Competência no formato `YYYY-MM`, que é como **toda** rota do backend indexa
/// mês.
///
/// String em vez de `DateTime` de propósito: `DateTime` carrega dia, hora e fuso,
/// e é exatamente aí que nasce o bug de competência — um `DateTime` à meia-noite
/// local em fuso positivo lido como UTC volta para o mês anterior. O backend já
/// trata disso desligando a conversão de `DATE` no driver do Postgres; do lado do
/// app, não converter para `DateTime` resolve na origem.
abstract final class Month {
  /// Faixa que o backend aceita. Fora dela ele responde 400, então a navegação
  /// para nos limites em vez de gerar requisição inválida.
  ///
  /// Os dois números são os `MIN_YEAR`/`MAX_YEAR` do `shared/http/schemas.ts`.
  /// Apertar só deste lado não protege nada e não é o que a constante promete:
  /// mudar aqui pede mudar lá junto.
  static const minYear = 2000;
  static const maxYear = 2100;

  static const _names = [
    'Janeiro',
    'Fevereiro',
    'Março',
    'Abril',
    'Maio',
    'Junho',
    'Julho',
    'Agosto',
    'Setembro',
    'Outubro',
    'Novembro',
    'Dezembro',
  ];

  static const _shortNames = [
    'jan',
    'fev',
    'mar',
    'abr',
    'mai',
    'jun',
    'jul',
    'ago',
    'set',
    'out',
    'nov',
    'dez',
  ];

  /// Competência corrente, do relógio do dispositivo.
  static String current() {
    final now = DateTime.now();
    return of(now.year, now.month);
  }

  /// Monta a partir de ano e mês, com o zero à esquerda que o backend exige.
  static String of(int year, int month) =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';

  static bool isValid(String month) {
    final parsed = _parse(month);
    if (parsed == null) return false;
    return parsed.year >= minYear && parsed.year <= maxYear;
  }

  /// `'2026-08'` → `'Agosto 2026'`. Devolve a própria string se não for válida,
  /// para um dado inesperado não virar exceção no meio de um `build`.
  static String label(String month) {
    final parsed = _parse(month);
    if (parsed == null) return month;
    return '${_names[parsed.month - 1]} ${parsed.year}';
  }

  /// Um intervalo de competências, para vigência e período de cadastro:
  /// `('2026-01', '2026-10')` → `'Janeiro 2026 a outubro 2026'`,
  /// `('2026-01', null)` → `'Desde janeiro 2026'`, e o mês sozinho quando os
  /// dois são iguais.
  ///
  /// O segundo mês vem em minúscula porque está no meio da frase — `label`
  /// capitaliza, e "a Outubro 2026" lê como erro de digitação.
  static String periodLabel(String from, String? to) {
    if (to == null) return 'Desde ${label(from).toLowerCase()}';
    if (to == from) return label(from);
    return '${label(from)} a ${label(to).toLowerCase()}';
  }

  /// `'2026-08'` → `'ago/2026'`. Para espaço apertado: chip, eixo de gráfico.
  static String shortLabel(String month) {
    final parsed = _parse(month);
    if (parsed == null) return month;
    return '${_shortNames[parsed.month - 1]}/${parsed.year}';
  }

  /// Só o nome do mês: `'2026-08'` → `'Agosto'`.
  static String monthName(String month) {
    final parsed = _parse(month);
    if (parsed == null) return month;
    return _names[parsed.month - 1];
  }

  /// Mês seguinte, virando o ano quando passa de dezembro.
  ///
  /// No limite superior devolve a própria competência — evita gerar `2101-01`,
  /// que o backend recusaria com 400.
  static String next(String month) => offset(month, 1);

  /// Mês anterior, virando o ano quando passa de janeiro.
  static String previous(String month) => offset(month, -1);

  /// Desloca [months] meses (negativo anda para trás), respeitando os limites.
  static String offset(String month, int months) {
    final parsed = _parse(month);
    if (parsed == null) return month;

    // Conta em meses absolutos desde o ano zero: a virada de ano cai fora sem
    // precisar de if para dezembro/janeiro.
    final total = parsed.year * 12 + (parsed.month - 1) + months;
    final year = total ~/ 12;
    final monthIndex = total % 12;

    if (year < minYear || year > maxYear) return month;

    return of(year, monthIndex + 1);
  }

  /// Há mês seguinte dentro da faixa aceita?
  static bool hasNext(String month) => next(month) != month;

  /// Há mês anterior dentro da faixa aceita?
  static bool hasPrevious(String month) => previous(month) != month;

  /// Sequência de [count] competências a partir de [month], inclusive. Para
  /// projeção e seletor de mês.
  static List<String> range(String month, int count) {
    if (count <= 0) return const [];
    return List.generate(
      count,
      (index) => offset(month, index),
      growable: false,
    );
  }

  /// Negativo se [a] vem antes de [b], zero se iguais, positivo se depois.
  /// Comparação lexicográfica funciona porque o formato é fixo e zero-padded.
  static int compare(String a, String b) => a.compareTo(b);

  static bool isBefore(String a, String b) => compare(a, b) < 0;
  static bool isAfter(String a, String b) => compare(a, b) > 0;

  /// É a competência corrente?
  static bool isCurrent(String month) => month == current();

  static ({int year, int month})? _parse(String value) {
    if (value.length != 7 || value[4] != '-') return null;

    final year = int.tryParse(value.substring(0, 4));
    final month = int.tryParse(value.substring(5, 7));

    if (year == null || month == null) return null;
    if (month < 1 || month > 12) return null;

    return (year: year, month: month);
  }
}
