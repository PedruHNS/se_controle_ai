/// Uma parcela: o valor de um mês específico de uma compra parcelada.
///
/// **Não é uma vigência.** Vigência responde "quanto vale este mês?" para uma
/// cobrança sem fim conhecido; uma parcela já nasce com valor, número e mês
/// definidos — `3/10 de R$ 350,00 em maio` é um fato, não uma regra vigente. Por
/// isso gasto fixo e gasto parcelado têm fontes da verdade diferentes, e nenhum
/// gasto tem as duas (GFX-09).
class InstallmentModel {
  const InstallmentModel({
    required this.number,
    required this.total,
    required this.amountCents,
    required this.referenceMonth,
  });

  /// De 1 a [total].
  final int number;

  /// O "de N" exibido. **Muda quando a compra é reparcelada** (GPR-11): as
  /// parcelas antigas de um 10x que virou 12x passam a exibir `1/12`, porque é
  /// a mesma compra, agora em 12 vezes.
  final int total;

  final int amountCents;

  /// Competência `YYYY-MM` em que esta parcela é cobrada.
  final String referenceMonth;

  /// `'3/10'` — o mesmo texto que o backend devolve em `installmentLabel` para
  /// a competência consultada. Montado aqui porque a listagem sem `?month` não
  /// traz o campo, e a tela precisa dele mesmo assim.
  String get label => '$number/$total';

  factory InstallmentModel.fromJson(Map<String, dynamic> json) =>
      InstallmentModel(
        number: json['number'] as int,
        total: json['total'] as int,
        amountCents: json['amountCents'] as int,
        referenceMonth: json['referenceMonth'] as String,
      );
}
