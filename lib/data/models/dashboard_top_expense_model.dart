/// Uma linha do card 7: um dos cinco maiores gastos cobrados na competência
/// (DSH-23).
///
/// É o detalhe do card 2 — lá a pergunta é para onde o dinheiro foi, aqui é
/// quais foram os maiores. Um mês com menos de cinco gastos devolve menos de
/// cinco linhas.
class DashboardTopExpenseModel {
  const DashboardTopExpenseModel({
    required this.id,
    required this.description,
    required this.amountCents,
    required this.spentAt,
    required this.installmentLabel,
  });

  final String id;
  final String description;

  /// O valor **da parcela**, quando o gasto é parcelado — e é o
  /// [installmentLabel] que explica por que ele é esse.
  final int amountCents;

  /// O dia da compra (GFX-12), ISO 8601. Não é o dia da cobrança: a geladeira
  /// parcelada aparece com a data em que foi comprada.
  final String spentAt;

  /// `'3/10'`, ou null quando o gasto não é parcelado.
  final String? installmentLabel;

  factory DashboardTopExpenseModel.fromJson(Map<String, dynamic> json) =>
      DashboardTopExpenseModel(
        id: json['id'] as String,
        description: json['description'] as String,
        amountCents: json['amountCents'] as int,
        spentAt: json['spentAt'] as String,
        installmentLabel: json['installmentLabel'] as String?,
      );

  @override
  String toString() =>
      'DashboardTopExpenseModel(id: $id, description: $description, amountCents: $amountCents, spentAt: $spentAt, installmentLabel: $installmentLabel)';
}
