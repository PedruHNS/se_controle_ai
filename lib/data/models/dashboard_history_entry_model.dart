/// Uma barra do card 6: ganho e gasto de uma competência da janela de seis
/// meses.
///
/// São seis meses terminando na competência pedida, **inclusive** (DSH-20) —
/// de `mês−5` a `mês`. Mês sem movimento vem zerado, não omitido (DSH-21), e a
/// entrada da competência pedida bate com o `totals` do topo (DSH-22): é a
/// barra que o card destaca.
///
/// É o que sobrou da tela de projeção: ela respondia "quanto vou ter juntado",
/// e virou uma linha de contexto olhando para trás.
class DashboardHistoryEntryModel {
  const DashboardHistoryEntryModel({
    required this.month,
    required this.incomeCents,
    required this.expenseCents,
  });

  /// `YYYY-MM`.
  final String month;

  final int incomeCents;
  final int expenseCents;

  factory DashboardHistoryEntryModel.fromJson(Map<String, dynamic> json) =>
      DashboardHistoryEntryModel(
        month: json['month'] as String,
        incomeCents: json['incomeCents'] as int,
        expenseCents: json['expenseCents'] as int,
      );

  @override
  String toString() =>
      'DashboardHistoryEntryModel(month: $month, incomeCents: $incomeCents, expenseCents: $expenseCents)';
}
