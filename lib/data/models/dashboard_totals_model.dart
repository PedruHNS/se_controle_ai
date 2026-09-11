/// O bloco `totals` do dashboard — os mesmos quatro números que
/// `GET /summary/balance` devolve para a competência (DSH-03).
///
/// É contrato, não coincidência: a spec fixa que as duas rotas nunca discordam,
/// e o teste de contrato confere isso.
class DashboardTotalsModel {
  const DashboardTotalsModel({
    required this.incomeCents,
    required this.expenseCents,
    required this.balanceCents,
    required this.committedPercent,
  });

  final int incomeCents;
  final int expenseCents;

  /// `incomeCents - expenseCents`. Negativo = mês no vermelho.
  final int balanceCents;

  /// Percentual do ganho já comprometido. Null quando não há ganho no mês —
  /// dividir por zero não teria sentido (RES-04).
  final double? committedPercent;

  factory DashboardTotalsModel.fromJson(Map<String, dynamic> json) =>
      DashboardTotalsModel(
        incomeCents: json['incomeCents'] as int,
        expenseCents: json['expenseCents'] as int,
        balanceCents: json['balanceCents'] as int,
        committedPercent: (json['committedPercent'] as num?)?.toDouble(),
      );

  @override
  String toString() =>
      'DashboardTotalsModel(incomeCents: $incomeCents, expenseCents: $expenseCents, balanceCents: $balanceCents, committedPercent: $committedPercent)';
}
