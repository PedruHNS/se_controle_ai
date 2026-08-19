/// Uma vigência de valor: quanto o ganho valia, e de quando até quando.
///
/// É o que torna "aumento em novembro não muda setembro" verificável na tela —
/// o histórico completo vem do backend, não é reconstruído aqui.
class IncomeVersionModel {
  const IncomeVersionModel({
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

  factory IncomeVersionModel.fromJson(Map<String, dynamic> json) =>
      IncomeVersionModel(
        amountCents: json['amountCents'] as int,
        validFrom: json['validFrom'] as String,
        validTo: json['validTo'] as String?,
      );
}
