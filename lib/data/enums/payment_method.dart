/// Como o gasto é pago. O backend só aceita estes dois (GFX-01).
enum PaymentMethod {
  creditCard('CREDIT_CARD'),
  debit('DEBIT');

  const PaymentMethod(this.wire);

  /// O valor como o backend o escreve. Não é o `name` do enum: lá é
  /// `SCREAMING_SNAKE`, aqui é `lowerCamel`, e traduzir por `toUpperCase()`
  /// funcionaria por acaso hoje e quebraria no primeiro valor com duas
  /// palavras.
  final String wire;

  static PaymentMethod fromWire(String value) =>
      values.firstWhere((method) => method.wire == value);

  /// Como [fromWire], mas devolve nulo em vez de estourar no valor
  /// desconhecido. É para ler o que vem de fora do app — hoje a query da rota
  /// da lista de gastos, que qualquer um pode digitar errado.
  static PaymentMethod? tryFromWire(String? value) =>
      value == null ? null : values.where((m) => m.wire == value).firstOrNull;
}
