/// Uma vigência de valor: quanto algo valia, e de quando até quando.
///
/// É o que torna "aumento em novembro não muda setembro" verificável na tela —
/// o histórico completo vem do backend, não é reconstruído aqui.
///
/// Serve a ganho e a gasto fixo porque os dois leem o **mesmo** motor de
/// vigência no backend (`AmountTimeline`, CONC-09 a CONC-12) e o `history`
/// chega com o mesmo formato dos dois lados. O que não se junta são as
/// operações — reajustar um ganho e reajustar um gasto são casos de uso
/// separados lá, e repositórios separados aqui.
class AmountVersionModel {
  const AmountVersionModel({
    required this.amountCents,
    required this.validFrom,
    required this.validTo,
  });

  final int amountCents;

  /// Competência `YYYY-MM` em que este valor passou a valer, inclusiva.
  final String validFrom;

  /// Última competência com este valor, inclusiva. Null = vigência em aberto.
  final String? validTo;

  /// Vigência em aberto é a que ainda recebe reajuste e correção.
  bool get isOpen => validTo == null;

  factory AmountVersionModel.fromJson(Map<String, dynamic> json) =>
      AmountVersionModel(
        amountCents: json['amountCents'] as int,
        validFrom: json['validFrom'] as String,
        validTo: json['validTo'] as String?,
      );
}
