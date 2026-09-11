/// Uma barra do card 4: a fatura de um cartão na competência, dentro do trilho
/// do limite.
///
/// **Todo cartão cadastrado aparece**, mesmo sem gasto no mês, com
/// `totalCents: 0` (DSH-16) — some da tela só quem foi excluído do cadastro.
class DashboardCardModel {
  const DashboardCardModel({
    required this.cardId,
    required this.label,
    required this.totalCents,
    required this.limitCents,
  });

  final String cardId;

  /// Pronto para mostrar — `'Nubank ••••1234'`, ou só o nome quando o cartão
  /// não tem dígitos cadastrados.
  final String label;

  final int totalCents;

  /// Null quando o cartão não tem limite cadastrado, que é opcional (CAR-01).
  /// Aí o card mostra o valor da fatura **sem trilho** (DSH-17): não inventa um
  /// limite, nem esconde o cartão.
  final int? limitCents;

  factory DashboardCardModel.fromJson(Map<String, dynamic> json) =>
      DashboardCardModel(
        cardId: json['cardId'] as String,
        label: json['label'] as String,
        totalCents: json['totalCents'] as int,
        limitCents: json['limitCents'] as int?,
      );

  @override
  String toString() =>
      'DashboardCardModel(cardId: $cardId, label: $label, totalCents: $totalCents, limitCents: $limitCents)';
}
