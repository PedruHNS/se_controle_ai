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

  /// A data ainda não chegou?
  ///
  /// Existe porque o calendário do gasto passou a aceitar o futuro (o dia é o
  /// único campo de tempo do formulário, e sem futuro não haveria como lançar
  /// o IPVA de janeiro). Uma tela que escreve "Compra em 10/01/2027" numa data
  /// que não chegou está afirmando o que não aconteceu.
  static bool isFuture(String isoDate) {
    if (isoDate.length != 10) return false;

    final date = DateTime.tryParse(isoDate);
    if (date == null) return false;

    final now = DateTime.now();

    return date.isAfter(DateTime(now.year, now.month, now.day));
  }

  /// `2026-08-17T23:30:00.000Z` → `2026-08-17` **no fuso do aparelho**.
  ///
  /// O `spentAt` do gasto (GFX-12) é a única data do contrato que não é
  /// `DATE`: é um instante, porque quem não escolhe o dia recebe o momento do
  /// cadastro. Cortar a string em dez caracteres daria o dia em UTC — às 21h
  /// de Brasília isso já é o dia seguinte, e o app mostraria uma compra de
  /// hoje como se fosse amanhã. Converter instante em dia é justamente a conta
  /// que precisa de fuso, então aqui `DateTime` é a ferramenta certa, e não a
  /// armadilha da decisão 3: ele entra, resolve o fuso e sai como string.
  ///
  /// Devolve null no que não for instante reconhecível — data ausente é a
  /// resposta certa para o ganho, que nunca teve dia de compra.
  static String? fromInstant(String? instant) {
    if (instant == null) return null;

    final parsed = DateTime.tryParse(instant);
    if (parsed == null) return null;

    final local = parsed.toLocal();

    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }
}
