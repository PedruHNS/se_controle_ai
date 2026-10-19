import 'amount_version_model.dart';

class IncomeModel {
  final String id;
  final String description;
  final bool recurring;
  final String startMonth;
  final String? endMonth;

  /// Nulo quando o ganho não vigora na competência pedida (GAN-12).
  final int? amountCents;
  final List<AmountVersionModel> history;
  const IncomeModel({
    required this.id,
    required this.description,
    required this.recurring,
    required this.startMonth,
    required this.endMonth,
    required this.amountCents,
    required this.history,
  });

  factory IncomeModel.fromJson(Map<String, dynamic> json) => IncomeModel(
    id: json['id'] as String,
    description: json['description'] as String,
    recurring: json['recurring'] as bool,
    startMonth: json['startMonth'] as String,
    endMonth: json['endMonth'] as String?,
    amountCents: json['amountCents'] as int?,
    history: (json['history'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(AmountVersionModel.fromJson)
        .toList(growable: false),
  );

  @override
  String toString() =>
      'IncomeModel(id: $id, description: $description, '
      'recurring: $recurring, startMonth: $startMonth, endMonth: $endMonth, '
      'amountCents: $amountCents, history: $history)';
}
