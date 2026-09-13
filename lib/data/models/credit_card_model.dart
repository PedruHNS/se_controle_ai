/// Um cartão de crédito cadastrado.
///
/// **Não confundir com `CreditCardInvoiceModel`.** Aquele é a *fatura* de um mês,
/// como ela aparece dentro de `/summary`: total, itens, uso do limite. Este é o
/// cartão em si, como o CRUD de `/credit-cards` o devolve. Os campos não se
/// sobrepõem o suficiente para um servir ao outro.
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

  /// Derivado pelo backend (CAR-06): `"Nubank ••••1234"`, ou só o nome quando
  /// não há dígitos. Vem pronto e é usado como vem — recalcular aqui seria a
  /// mesma regra escrita duas vezes, em dois lugares que podem discordar.

  /// Quatro dígitos, ou null. Opcional e limpável (CAR-01).

  /// Dia do fechamento, 1 a 31 (CAR-02).

  /// Dia do vencimento, 1 a 31 (CAR-02).

  /// Limite em centavos, ou null quando não informado. Opcional e limpável.

  /// Vencimento da fatura da competência consultada, `YYYY-MM-DD`.
  ///
  /// **Null quando a busca vai sem `?month`** — não há competência, então não há
  /// o que vencer. Quem exibe precisa tratar os dois casos.

  /// Quanto já foi lançado no cartão na competência consultada, em centavos
  /// (CAR-09).
  ///
  /// **Null quando a busca vai sem `?month`**, como o [dueDate] — sem
  /// competência não há fatura para somar. Zero é diferente de null: significa
  /// que o mês foi consultado e a fatura está limpa.

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
