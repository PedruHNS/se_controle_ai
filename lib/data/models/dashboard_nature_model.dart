/// O card 5: quanto do mês já estava vendido antes de ele começar.
///
/// As três naturezas são derivadas pelo backend, nunca guardadas (DSH-18), e
/// todo gasto cai em exatamente uma delas — a soma é o `expenseCents` do topo
/// (DSH-19). Dois meses de total idêntico podem ser vidas diferentes, e é isso
/// que o card mostra.
class DashboardNatureModel {
  const DashboardNatureModel({
    required this.recurringCents,
    required this.installmentCents,
    required this.oneOffCents,
  });

  /// Gasto fixo com vigência em aberto. Recorrência é do **gasto**, não da
  /// vigência que cobre o mês: um aluguel reajustado em abril continua
  /// recorrente em janeiro (CONC-13).
  final int recurringCents;

  /// A parcela daquele mês. Parcelado nunca é recorrente.
  final int installmentCents;

  /// Gasto fixo sem nenhuma vigência em aberto — o avulso. Inclui o recorrente
  /// já encerrado, que é consequência assumida do CONC-13.
  final int oneOffCents;

  factory DashboardNatureModel.fromJson(Map<String, dynamic> json) =>
      DashboardNatureModel(
        recurringCents: json['recurringCents'] as int,
        installmentCents: json['installmentCents'] as int,
        oneOffCents: json['oneOffCents'] as int,
      );

  @override
  String toString() =>
      'DashboardNatureModel(recurringCents: $recurringCents, installmentCents: $installmentCents, oneOffCents: $oneOffCents)';
}
