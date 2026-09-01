/// Um cartão de crédito cadastrado.
///
/// **Não confundir com `CreditCardInvoiceModel`.** Aquele é a *fatura* de um mês,
/// como ela aparece dentro de `/summary`: total, itens, uso do limite. Este é o
/// cartão em si, como o CRUD de `/credit-cards` o devolve. Os campos não se
/// sobrepõem o suficiente para um servir ao outro.
class CreditCardModel {
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

  final String id;
  final String name;

  /// Derivado pelo backend (CAR-06): `"Nubank ••••1234"`, ou só o nome quando
  /// não há dígitos. Vem pronto e é usado como vem — recalcular aqui seria a
  /// mesma regra escrita duas vezes, em dois lugares que podem discordar.
  final String label;

  /// Quatro dígitos, ou null. Opcional e limpável (CAR-01).
  final String? lastDigits;

  /// Dia do fechamento, 1 a 31 (CAR-02).
  final int closingDay;

  /// Dia do vencimento, 1 a 31 (CAR-02).
  final int dueDay;

  /// Limite em centavos, ou null quando não informado. Opcional e limpável.
  final int? limitCents;

  /// Vencimento da fatura da competência consultada, `YYYY-MM-DD`.
  ///
  /// **Null quando a busca vai sem `?month`** — não há competência, então não há
  /// o que vencer. Quem exibe precisa tratar os dois casos.
  final String? dueDate;

  /// Quanto já foi lançado no cartão na competência consultada, em centavos
  /// (CAR-09).
  ///
  /// **Null quando a busca vai sem `?month`**, como o [dueDate] — sem
  /// competência não há fatura para somar. Zero é diferente de null: significa
  /// que o mês foi consultado e a fatura está limpa.
  final int? totalCents;

  bool get hasLimit => limitCents != null;

  /// A fatura vence no mês **seguinte** ao da competência?
  ///
  /// Espelha o CAR-03 — `dueDay > closingDay` vence no próprio mês, senão no
  /// seguinte — e existe só para a tela **explicar** a data enquanto a pessoa
  /// escolhe os dias, antes de haver qualquer `dueDate` para mostrar. A data que
  /// vale continua sendo a que o backend calcula.
  bool get dueInNextMonth => dueDay <= closingDay;

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
}
