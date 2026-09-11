/// O card 3: a curva do ritmo do mês.
///
/// A série é só das **compras feitas nesta competência** — lançamento cujo
/// `spentAt` cai dentro do mês (DSH-11). A parcela 3/10 é cobrada agora mas foi
/// comprada em julho, e o aluguel tem `spentAt` de quando começou; nenhum dos
/// dois entra na curva, e os dois estão no [baselineCents].
class DashboardDailyModel {
  const DashboardDailyModel({
    required this.baselineCents,
    required this.days,
    required this.previousDays,
  });

  /// O que ficou fora da curva: fixos e parcelas de compras antigas. É a linha
  /// de base do desenho, e existe para o invariante do DSH-12 fechar —
  /// `baselineCents + Σ days = totals.expenseCents`. Sem ela metade do mês
  /// sumiria do gráfico sem ninguém perceber.
  final int baselineCents;

  /// O mês inteiro, do dia 1 ao último, em qualquer `scope` e sem buracos:
  /// dia sem compra vem zerado (DSH-13 e DSH-14). Não é truncada em "hoje"
  /// porque compra com data futura é permitida — quem para a linha no dia de
  /// hoje é a tela, que sabe que dia é.
  final List<DashboardDayModel> days;

  /// A mesma série da competência anterior, para a curva apagada do fundo
  /// (DSH-15). É ela que responde "isso é normal para mim?", e não custa
  /// requisição: sai da mesma janela de seis meses.
  final List<DashboardDayModel> previousDays;

  factory DashboardDailyModel.fromJson(Map<String, dynamic> json) =>
      DashboardDailyModel(
        baselineCents: json['baselineCents'] as int,
        days: _serie(json['days']),
        previousDays: _serie(json['previousDays']),
      );

  static List<DashboardDayModel> _serie(dynamic value) =>
      (value as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(DashboardDayModel.fromJson)
          .toList(growable: false);

  @override
  String toString() =>
      'DashboardDailyModel(baselineCents: $baselineCents, '
      'days: ${days.length} dias, previousDays: ${previousDays.length} dias)';
}

/// Um ponto da curva. Mora aqui e não em arquivo próprio porque não existe
/// fora da série: são dois campos que só fazem sentido dentro do card 3.
class DashboardDayModel {
  const DashboardDayModel({required this.day, required this.amountCents});

  /// O dia do mês, de 1 a 31.
  final int day;

  final int amountCents;

  factory DashboardDayModel.fromJson(Map<String, dynamic> json) =>
      DashboardDayModel(
        day: json['day'] as int,
        amountCents: json['amountCents'] as int,
      );

  @override
  String toString() =>
      'DashboardDayModel(day: $day, amountCents: $amountCents)';
}
