/// Data no formato `YYYY-MM-DD`, que é como o backend devolve toda data — o
/// `dueDate` da fatura e o do cartão (CAR-03).
///
/// String em vez de `DateTime`, pela mesma razão do [Month]: `DateTime` carrega
/// hora e fuso, e é aí que a data anda um dia para trás. O backend já desliga a
/// conversão de `DATE` no driver do Postgres; do lado do app, formatar por corte
/// de string mantém a garantia de ponta a ponta.
///
/// Nasceu privado dentro do `CreditCardInvoiceCard`. Subiu para cá quando o CRUD
/// de cartões passou a precisar do mesmo formato.
abstract final class IsoDate {
  /// `2026-08-17` → `17/08`. Sem o ano, para quando o contexto já o diz — é o
  /// caso da fatura, que está sob o mês exibido.
  ///
  /// Devolve a entrada intacta se ela não tiver o tamanho de uma data ISO: um
  /// rótulo estranho na tela é melhor que uma exceção durante o `build`.
  static String label(String isoDate) {
    if (isoDate.length != 10) return isoDate;
    return '${isoDate.substring(8, 10)}/${isoDate.substring(5, 7)}';
  }

  /// `2026-08-17` → `17/08/2026`. Para quando a data aparece sozinha, fora de
  /// uma tela que já fixa a competência.
  static String fullLabel(String isoDate) {
    if (isoDate.length != 10) return isoDate;
    return '${label(isoDate)}/${isoDate.substring(0, 4)}';
  }
}
