import 'month_utils.dart';

/// As contas de competência de um cartão: em que fatura uma compra cai, e em
/// que mês essa fatura é paga.
///
/// Moram aqui, e não no `CreditCardModel`, porque model não tem nada derivado
/// — é a regra em `.claude/rules/models.md`. Dos três destinos que a regra
/// oferece, este é o do meio: **a mesma regra serve a telas diferentes**. O
/// formulário de gasto usa as duas contas inteiras para achar a competência, e
/// o formulário de cartão usa só o [closesInPreviousMonth], para explicar o
/// deslocamento enquanto a pessoa escolhe os dias.
///
/// **Recebe os dias, e não o cartão**, e é o que permite as duas telas. No
/// formulário de cartão ainda não existe `CreditCardModel` nenhum: os dias
/// estão sendo digitados, e são dois `int?` soltos do `FormGroup`.
///
/// Tudo aqui é corte de string em `YYYY-MM` e `YYYY-MM-DD`, sem `DateTime` no
/// caminho — a mesma escolha do [MonthUtils] e do `IsoDateUtils`, e pelo mesmo motivo:
/// `DateTime` com fuso faz uma data andar um dia para trás. A única exceção é
/// o [openInvoiceMonth], que precisa saber que dia é hoje.
abstract final class CreditCardMonthsUtils {
  /// A fatura fecha no mês **anterior** ao que lhe dá nome?
  ///
  /// Desde a CAR-03 de 12/09/2026 a competência é o mês do **pagamento**, então
  /// num cartão que vence antes de fechar (`dueDay <= closingDay`) a fatura de
  /// outubro é a que fechou em setembro.
  ///
  /// O `<=` inclui o empate de propósito: um cartão que fecha e vence no dia 10
  /// não cobra no mesmo dia em que fecha, então o empate se comporta como
  /// "vence antes de fechar".
  static bool closesInPreviousMonth({
    required int closingDay,
    required int dueDay,
  }) => dueDay <= closingDay;

  /// Em qual **fatura** cai uma compra feita em [isoDate] (`YYYY-MM-DD`) — pelo
  /// fechamento, sem ainda dizer quando ela é paga.
  ///
  /// Até o dia do fechamento a compra entra na fatura que fecha neste mês; do
  /// dia seguinte em diante ela já é da próxima.
  ///
  /// Sem isto o app deixava a compra do dia 8, num cartão que fecha dia 5, na
  /// fatura que fechou três dias antes — o gasto aparecia num mês em que
  /// ninguém iria pagá-lo.
  static String closingMonthFor(String isoDate, {required int closingDay}) {
    if (isoDate.length != 10) return isoDate;

    final month = isoDate.substring(0, 7);
    final day = int.tryParse(isoDate.substring(8, 10));
    if (day == null) return month;

    return day <= closingDay ? month : MonthUtils.next(month);
  }

  /// A **competência** de uma compra feita em [isoDate]: o mês em que a fatura
  /// dela é paga.
  ///
  /// Duas contas em sequência, e é a segunda que entrou em 12/09/2026. A
  /// primeira acha a fatura pelo fechamento ([closingMonthFor]); a segunda diz
  /// em que mês essa fatura vence — no próprio, quando `dueDay > closingDay`,
  /// ou no seguinte.
  ///
  /// Antes a competência parava na primeira conta, e o mês do gasto era o do
  /// fechamento. Num cartão que fecha 31 e vence 5 isso deslocava tudo: a
  /// compra de 12/09 ia para "setembro", mas só saía da conta em 05/10 — e a
  /// fatura paga em 05/09 se chamava agosto. Agora a competência quer dizer a
  /// mesma coisa no cartão e no débito: **o mês em que o dinheiro sai**.
  static String invoiceMonthFor(
    String isoDate, {
    required int closingDay,
    required int dueDay,
  }) {
    final closing = closingMonthFor(isoDate, closingDay: closingDay);
    if (closing.length != 7) return closing;

    return closesInPreviousMonth(closingDay: closingDay, dueDay: dueDay)
        ? MonthUtils.next(closing)
        : closing;
  }

  /// A fatura que ainda aceita lançamento — a que vai fechar hoje ou depois.
  ///
  /// [now] existe para o teste não depender do relógio; em produção ninguém
  /// passa nada.
  static String openInvoiceMonth({
    required int closingDay,
    required int dueDay,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();

    return invoiceMonthFor(
      '${today.year.toString().padLeft(4, '0')}-'
      '${today.month.toString().padLeft(2, '0')}-'
      '${today.day.toString().padLeft(2, '0')}',
      closingDay: closingDay,
      dueDay: dueDay,
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
  static String chargeMonthFor(
    String isoDate, {
    required int closingDay,
    required int dueDay,
    DateTime? now,
  }) {
    final purchase = invoiceMonthFor(
      isoDate,
      closingDay: closingDay,
      dueDay: dueDay,
    );
    final open = openInvoiceMonth(
      closingDay: closingDay,
      dueDay: dueDay,
      now: now,
    );

    return MonthUtils.isBefore(purchase, open) ? open : purchase;
  }
}
