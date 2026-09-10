import '../../core/utils/month.dart';

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

  /// Em qual fatura cai uma compra feita em [isoDate] (`YYYY-MM-DD`).
  ///
  /// Até o dia do fechamento a compra entra na fatura que fecha neste mês; do
  /// dia seguinte em diante ela já é da próxima. É a mesma regra do CAR-03
  /// vista do outro lado: em vez de "quando vence", "o que ainda entra".
  ///
  /// Sem isto o app deixava a compra do dia 8, num cartão que fecha dia 5, na
  /// fatura que fechou três dias antes — o gasto aparecia num mês em que
  /// ninguém iria pagá-lo.
  String invoiceMonthFor(String isoDate) {
    if (isoDate.length != 10) return isoDate;

    final month = isoDate.substring(0, 7);
    final day = int.tryParse(isoDate.substring(8, 10));
    if (day == null) return month;

    return day <= closingDay ? month : Month.next(month);
  }

  /// A fatura que ainda aceita lançamento — a que vai fechar hoje ou depois.
  ///
  /// [now] existe para o teste não depender do relógio; em produção ninguém
  /// passa nada.
  String openInvoiceMonth([DateTime? now]) {
    final today = now ?? DateTime.now();

    return invoiceMonthFor(
      '${today.year.toString().padLeft(4, '0')}-'
      '${today.month.toString().padLeft(2, '0')}-'
      '${today.day.toString().padLeft(2, '0')}',
    );
  }

  /// Em qual fatura o gasto vai ser **cobrado**: a da data da compra, ou a
  /// primeira ainda aberta quando aquela já fechou.
  ///
  /// [invoiceMonthFor] responde onde a compra caberia; esta responde onde ela
  /// cabe. Faturas fechadas não recebem lançamento novo — foi o que aconteceu
  /// em 10/09/2026 com um cartão que fecha dia 1: a compra do dia 1 foi parar
  /// na fatura de setembro, que tinha fechado naquele mesmo dia, e a primeira
  /// parcela apareceu num mês que já estava encerrado.
  ///
  /// O preço disso é assumido: uma compra antiga lançada com atraso entra na
  /// fatura aberta, e não naquela em que ela foi cobrada de verdade. Entre
  /// mexer numa fatura fechada e adiar a cobrança para a aberta, a segunda é
  /// a que ainda dá para pagar.
  String chargeMonthFor(String isoDate, {DateTime? now}) {
    final purchase = invoiceMonthFor(isoDate);
    final open = openInvoiceMonth(now);

    return Month.isBefore(purchase, open) ? open : purchase;
  }

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
