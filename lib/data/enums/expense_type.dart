/// Fixo (valor versionado por vigência) ou parcelado (parcelas materializadas).
///
/// Cada tipo tem exatamente uma fonte da verdade para o dinheiro (GFX-09): um
/// `FIXED` nunca tem parcelas, um `INSTALLMENT` nunca tem vigências.
enum ExpenseType {
  fixed('FIXED'),
  installment('INSTALLMENT');

  const ExpenseType(this.wire);

  final String wire;

  static ExpenseType fromWire(String value) =>
      values.firstWhere((type) => type.wire == value);
}
