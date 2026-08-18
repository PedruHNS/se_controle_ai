/// Uma linha do resumo — serve para ganho, gasto no débito e item de fatura.
class SummaryLineItemModel {
  const SummaryLineItemModel({
    required this.id,
    required this.description,
    required this.amountCents,
    required this.installmentLabel,
  });

  final String id;
  final String description;
  final int amountCents;

  /// `"3/10"` quando a linha é uma parcela; null caso contrário.
  final String? installmentLabel;

  factory SummaryLineItemModel.fromJson(Map<String, dynamic> json) =>
      SummaryLineItemModel(
        id: json['id'] as String,
        description: json['description'] as String,
        amountCents: json['amountCents'] as int,
        installmentLabel: json['installmentLabel'] as String?,
      );
}
