/// Um mês de `GET /summary/projection`.
class MonthProjection {
  final String month;
  final int incomeCents;
  final int expenseCents;
  final int balanceCents;

  /// Soma dos saldos até este mês — é o que responde "quanto vou ter juntado".
  final int cumulativeBalanceCents;

  const MonthProjection({
    required this.month,
    required this.incomeCents,
    required this.expenseCents,
    required this.balanceCents,
    required this.cumulativeBalanceCents,
  });

  factory MonthProjection.fromJson(Map<String, dynamic> json) =>
      MonthProjection(
        month: json['month'] as String,
        incomeCents: json['incomeCents'] as int,
        expenseCents: json['expenseCents'] as int,
        balanceCents: json['balanceCents'] as int,
        cumulativeBalanceCents: json['cumulativeBalanceCents'] as int,
      );
}
