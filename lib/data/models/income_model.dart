import 'amount_version_model.dart';
import 'tag_model.dart';

class IncomeModel {
  final String id;
  final String description;
  final TagModel? tag;
  final bool recurring;
  final String startMonth;
  final String? endMonth;
  final int amountCents;
  final List<AmountVersionModel> history;
  const IncomeModel({
    required this.id,
    required this.description,
    required this.tag,
    required this.recurring,
    required this.startMonth,
    required this.endMonth,
    required this.amountCents,
    required this.history,
  });

  factory IncomeModel.fromJson(Map<String, dynamic> json) => IncomeModel(
    id: json['id'] as String,
    description: json['description'] as String,
    tag: json['tag'] == null
        ? null
        : TagModel.fromJson(json['tag'] as Map<String, dynamic>),
    recurring: json['recurring'] as bool,
    startMonth: json['startMonth'] as String,
    endMonth: json['endMonth'] as String?,
    amountCents: json['amountCents'] as int,
    history: (json['history'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(AmountVersionModel.fromJson)
        .toList(growable: false),
  );

  @override
  String toString() =>
      'IncomeModel(id: $id, description: $description, tag: $tag, '
      'recurring: $recurring, startMonth: $startMonth, endMonth: $endMonth, '
      'amountCents: $amountCents, history: $history)';
}
