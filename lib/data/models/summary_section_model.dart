import 'package:se_controle_ai/data/models/summary_line_item_model.dart';

/// Uma seção da home: o total e as linhas que o compõem.
///
/// Serve ganhos e débito, que o backend devolve com a mesma forma —
/// `GET /summary/incomes` e `GET /summary/debit`. Chamava-se `DebitGroupModel`
/// enquanto só existia embutido no `/summary`; virou seção quando cada uma
/// ganhou rota própria.
class SummarySectionModel {
  const SummarySectionModel({required this.totalCents, required this.items});

  final int totalCents;
  final List<SummaryLineItemModel> items;

  bool get isEmpty => items.isEmpty;

  factory SummarySectionModel.fromJson(Map<String, dynamic> json) =>
      SummarySectionModel(
        totalCents: json['totalCents'] as int,
        items: (json['items'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map(SummaryLineItemModel.fromJson)
            .toList(growable: false),
      );
}
