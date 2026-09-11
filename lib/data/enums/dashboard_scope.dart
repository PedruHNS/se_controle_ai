/// O que o número do card 1 do dashboard significa, porque a pergunta muda com
/// a competência (DSH-06).
enum DashboardScope {
  /// A competência é a de hoje: quanto **ainda cabe** por dia, dividido pelos
  /// dias que faltam contando hoje (DSH-05).
  current('current'),

  /// Competência passada: a média diária realizada, pelo mês inteiro. Num mês
  /// que acabou não existe "ainda cabe".
  past('past'),

  /// Competência futura: o orçamento diário, pelo mês inteiro.
  future('future');

  const DashboardScope(this.wire);

  /// O valor como o backend o escreve. Igual ao `name` hoje, mas declarado
  /// como os outros enums do app — traduzir por coincidência quebraria no
  /// primeiro valor com duas palavras.
  final String wire;

  /// Valor desconhecido cai em [current] em vez de estourar: um `scope` novo no
  /// backend não pode derrubar a tela de um APK já instalado.
  static DashboardScope fromWire(String value) =>
      values.where((scope) => scope.wire == value).firstOrNull ?? current;
}
