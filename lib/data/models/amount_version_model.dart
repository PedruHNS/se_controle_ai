class AmountVersionModel {
  final int amountCents;
  final String validFrom;
  final String? validTo;

  const AmountVersionModel({
    required this.amountCents,
    required this.validFrom,
    required this.validTo,
  });

  factory AmountVersionModel.fromJson(Map<String, dynamic> json) =>
      AmountVersionModel(
        amountCents: json['amountCents'] as int,
        validFrom: json['validFrom'] as String,
        validTo: json['validTo'] as String?,
      );

  @override
  String toString() =>
      'AmountVersionModel(amountCents: $amountCents, validFrom: $validFrom, '
      'validTo: $validTo)';
}
