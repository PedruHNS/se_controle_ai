import 'package:flutter/material.dart';

import '../../../data/models/credit_card_invoice_model.dart';
import 'credit_card_invoice_card.dart';

/// As faturas do mês lado a lado, deslizando na horizontal.
///
/// Empilhadas, cada cartão novo empurrava o resto da home para baixo: com três
/// cartões a pessoa rolava meia tela de fatura para chegar ao fim do mês. Aqui
/// a seção ocupa a altura de uma fatura só, seja qual for o número de cartões.
///
/// O pedaço do próximo card à mostra ([_peek]) é o que conta que há mais coisa
/// para o lado — sem ele, um carrossel parece uma lista de um item só.
class InvoiceCarousel extends StatelessWidget {
  const InvoiceCarousel({
    required this.invoices,
    required this.onOpen,
    super.key,
  });

  final List<CreditCardInvoiceModel> invoices;

  /// Abre o cartão da fatura tocada.
  final void Function(CreditCardInvoiceModel invoice) onOpen;

  /// Quanto do próximo card fica aparecendo na borda.
  static const _peek = 40.0;

  /// Respiro entre um card e outro.
  static const _gap = 12.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Com um cartão só não há próximo para espiar, e estreitar o card
        // deixaria uma sobra à direita que parece defeito de alinhamento.
        final largura = invoices.length == 1
            ? constraints.maxWidth
            : constraints.maxWidth - _peek;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          // A sombra do `Card` é desenhada fora dos limites dele; recortando no
          // viewport ela some justo nas bordas, que é onde o card se destaca do
          // fundo.
          clipBehavior: Clip.none,
          // Sem `IntrinsicHeight` aqui: quem sabe a própria altura é o card,
          // que a fixa em `CreditCardInvoiceCard.alturaBase`. Tentar igualar as
          // alturas por intrínseca não funcionaria — ela é calculada como se
          // todo texto coubesse numa linha só, e um rótulo que quebra em duas
          // estoura o card em alguns pixels.
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (indice, invoice) in invoices.indexed)
                Padding(
                  padding: EdgeInsets.only(
                    right: indice == invoices.length - 1 ? 0 : _gap,
                  ),
                  child: SizedBox(
                    width: largura,
                    child: CreditCardInvoiceCard(
                      invoice: invoice,
                      onTap: () => onOpen(invoice),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
