/// Resposta de `GET /summary/balance?month=YYYY-MM` — os números do topo da
/// home.
///
/// Rota própria porque atravessa ganhos e gastos: nenhuma das três seções
/// enxerga os dois lados. Calcular no app obrigaria o card do topo a esperar as
/// quatro respostas, que é justamente o que separar as buscas veio evitar.
class MonthlyBalanceModel {
  const MonthlyBalanceModel({
    required this.month,
    required this.incomeCents,
    required this.expenseCents,
    required this.balanceCents,
    required this.committedPercent,
  });

  final String month;
  final int incomeCents;
  final int expenseCents;

  /// `incomeCents - expenseCents`. Negativo = mês no vermelho.
  final int balanceCents;

  /// Percentual do ganho já comprometido. Null quando não há ganho no mês
  /// (dividir por zero não teria sentido).
  final double? committedPercent;

  bool get isNegative => balanceCents < 0;

  factory MonthlyBalanceModel.fromJson(Map<String, dynamic> json) =>
      MonthlyBalanceModel(
        month: json['month'] as String,
        incomeCents: json['incomeCents'] as int,
        expenseCents: json['expenseCents'] as int,
        balanceCents: json['balanceCents'] as int,
        committedPercent: (json['committedPercent'] as num?)?.toDouble(),
      );
}
