import 'package:se_controle_ai/data/models/summary_line_item_model.dart';

class DebitGroup {
  const DebitGroup({required this.totalCents, required this.items});

  final int totalCents;
  final List<SummaryLineItemModel> items;

  bool get isEmpty => items.isEmpty;

  factory DebitGroup.fromJson(Map<String, dynamic> json) => DebitGroup(
    totalCents: json['totalCents'] as int,
    items: (json['items'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(SummaryLineItemModel.fromJson)
        .toList(growable: false),
  );
}
