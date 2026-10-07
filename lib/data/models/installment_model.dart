/// Uma parcela: o valor de um mês específico de uma compra parcelada.
///
/// **Não é uma vigência.** Vigência responde "quanto vale este mês?" para uma
/// cobrança sem fim conhecido; uma parcela já nasce com valor, número e mês
/// definidos — `3/10 de R$ 350,00 em maio` é um fato, não uma regra vigente. Por
/// isso gasto fixo e gasto parcelado têm fontes da verdade diferentes, e nenhum
/// gasto tem as duas (GFX-09).
class InstallmentModel {
  final int number;
  final int total;
  final int amountCents;
  final String referenceMonth;

  const InstallmentModel({
    required this.number,
    required this.total,
    required this.amountCents,
    required this.referenceMonth,
  });

  factory InstallmentModel.fromJson(Map<String, dynamic> json) =>
      InstallmentModel(
        number: json['number'] as int,
        total: json['total'] as int,
        amountCents: json['amountCents'] as int,
        referenceMonth: json['referenceMonth'] as String,
      );

  @override
  String toString() =>
      'InstallmentModel(number: $number, total: $total, '
      'amountCents: $amountCents, referenceMonth: $referenceMonth)';
}
