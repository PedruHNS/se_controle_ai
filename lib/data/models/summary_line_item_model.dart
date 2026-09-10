import '../../core/utils/iso_date.dart';
import 'tag_model.dart';

/// Uma linha do resumo — serve para ganho, gasto no débito e item de fatura.
class SummaryLineItemModel {
  const SummaryLineItemModel({
    required this.id,
    required this.description,
    required this.amountCents,
    required this.installmentLabel,
    required this.spentAt,
    required this.tag,
  });

  final String id;
  final String description;
  final int amountCents;

  /// O dia da compra (GFX-12) em `YYYY-MM-DD`, já no fuso do aparelho.
  ///
  /// Nulo em ganho, que não é compra, e também no gasto que vier de um backend
  /// anterior à GFX-12 — a linha some da tela, ela não estoura.
  final String? spentAt;

  /// `"3/10"` quando a linha é uma parcela; null caso contrário.
  final String? installmentLabel;

  /// TAG-12. Nulo só em ganho, que pode não ter rótulo (TAG-07) — em gasto o
  /// backend garante que sempre vem.
  final TagModel? tag;

  factory SummaryLineItemModel.fromJson(Map<String, dynamic> json) =>
      SummaryLineItemModel(
        id: json['id'] as String,
        description: json['description'] as String,
        amountCents: json['amountCents'] as int,
        installmentLabel: json['installmentLabel'] as String?,
        spentAt: IsoDate.fromInstant(json['spentAt'] as String?),
        tag: json['tag'] == null
            ? null
            : TagModel.fromJson(json['tag'] as Map<String, dynamic>),
      );
}
