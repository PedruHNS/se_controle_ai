/// Ordem alfabética como uma pessoa espera ver, e não como o Dart compara.
///
/// `compareTo` de String é ordem de **code unit**: toda maiúscula vem antes de
/// toda minúscula, e tudo que tem acento cai depois do `z`. Numa lista de tags
/// isso produz "Água" no fim, embaixo de "Zebra", e "aluguel" separado de
/// "Aluguel" — duas coisas que ninguém procura onde elas ficam.
///
/// Fora dos models de propósito: ordenar é decisão de quem exibe, não do dado.
/// Deixar isto dentro de [TagModel] faria a ordem alfabética virar *a* ordem da
/// classe, e listar por uso ou por data depois pediria comparador mesmo assim.
///
/// **Não é collation de verdade.** Um `intl.Collator` seguiria a regra do locale
/// para casos que este não cobre — ß, dígrafos, ordenação de números dentro do
/// texto. Para rótulos curtos em português, dobrar o acento e a caixa resolve o
/// que se vê, sem dependência nova.
abstract final class TextOrder {
  /// Comparador para `sort`, ignorando caixa e acento.
  ///
  /// ```dart
  /// tags.sort((a, b) => TextOrder.alfabetica(a.name, b.name));
  /// ```
  static int alfabetica(String a, String b) {
    final comparacao = _chave(a).compareTo(_chave(b));

    // Desempate pelo texto original: "Água" e "agua" têm a mesma chave e não são
    // o mesmo rótulo. Sem isto a ordem entre as duas dependeria do algoritmo de
    // ordenação, e mudaria sozinha ao inserir um item qualquer na lista.
    return comparacao != 0 ? comparacao : a.compareTo(b);
  }

  static String _chave(String texto) {
    final chave = StringBuffer();

    for (final letra in texto.toLowerCase().split('')) {
      chave.write(_semAcento[letra] ?? letra);
    }

    return chave.toString();
  }

  /// Só o que aparece em português. Letra fora daqui passa intacta — o pior
  /// caso é ela ordenar pelo code unit, que é o comportamento de antes.
  static const _semAcento = <String, String>{
    'á': 'a',
    'à': 'a',
    'â': 'a',
    'ã': 'a',
    'ä': 'a',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'í': 'i',
    'ì': 'i',
    'î': 'i',
    'ï': 'i',
    'ó': 'o',
    'ò': 'o',
    'ô': 'o',
    'õ': 'o',
    'ö': 'o',
    'ú': 'u',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ç': 'c',
    'ñ': 'n',
  };
}
