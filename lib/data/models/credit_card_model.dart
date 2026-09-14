class CreditCardModel {
  final String id;
  final String name;
  final String label;
  final String? lastDigits;
  final int closingDay;
  final int dueDay;
  final int? limitCents;
  final String? dueDate;
  final int? totalCents;

  const CreditCardModel({
    required this.id,
    required this.name,
    required this.label,
    required this.lastDigits,
    required this.closingDay,
    required this.dueDay,
    required this.limitCents,
    required this.dueDate,
    required this.totalCents,
  });

  factory CreditCardModel.fromJson(Map<String, dynamic> json) =>
      CreditCardModel(
        id: json['id'] as String,
        name: json['name'] as String,
        label: json['label'] as String,
        lastDigits: json['lastDigits'] as String?,
        closingDay: json['closingDay'] as int,
        dueDay: json['dueDay'] as int,
        limitCents: json['limitCents'] as int?,
        dueDate: json['dueDate'] as String?,
        totalCents: json['totalCents'] as int?,
      );

  @override
  String toString() =>
      'CreditCardModel(id: $id, name: $name, label: $label, '
      'lastDigits: $lastDigits, closingDay: $closingDay, dueDay: $dueDay, '
      'limitCents: $limitCents, dueDate: $dueDate, totalCents: $totalCents)';
}
