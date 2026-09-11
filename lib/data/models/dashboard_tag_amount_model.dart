/// Uma linha do card 2: quanto foi gasto numa tag na competência.
///
/// Não é o [TagModel] do cadastro — aqui não há `archived` nem `usageCount`, e
/// há o valor do mês. Vem ordenado do maior para o menor pelo backend
/// (DSH-09), e a soma de todas as linhas é o `expenseCents` do topo (DSH-10).
class DashboardTagAmountModel {
  const DashboardTagAmountModel({
    required this.id,
    required this.name,
    required this.color,
    required this.amountCents,
  });

  final String id;
  final String name;

  /// `#RRGGBB`, ou **null** em tag anterior à migration `010` (DSH-10). Aí quem
  /// escolhe a cor é o app — quem traduz o texto em `Color` é o card, não o
  /// model.
  final String? color;

  final int amountCents;

  factory DashboardTagAmountModel.fromJson(Map<String, dynamic> json) =>
      DashboardTagAmountModel(
        id: json['id'] as String,
        name: json['name'] as String,
        color: json['color'] as String?,
        amountCents: json['amountCents'] as int,
      );

  @override
  String toString() =>
      'DashboardTagAmountModel(id: $id, name: $name, color: $color, amountCents: $amountCents)';
}
