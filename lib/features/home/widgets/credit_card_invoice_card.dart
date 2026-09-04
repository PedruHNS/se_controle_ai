import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

import '../../../core/utils/iso_date.dart';
import '../../../core/utils/money.dart';
import '../../../data/models/credit_card_invoice_model.dart';
import 'line_item_tile.dart';

/// A fatura de um cartão no mês: total, vencimento, uso do limite e os itens.
///
/// Altura fixa, e por isso todo card tem o mesmo tamanho: lado a lado no
/// carrossel, alturas diferentes davam uma borda inferior serrilhada a cada
/// deslize. O preço é o vazio embaixo do cartão que gastou pouco.
///
/// Altura fixa só é segura se o conteúdo tiver tamanho previsível, então o
/// rótulo e a descrição de cada item vão limitados a uma linha. Sem isso um
/// nome comprido quebra em três linhas e o card pede 481px, contra os
/// [alturaBase] de projeto.
class CreditCardInvoiceCard extends StatelessWidget {
  const CreditCardInvoiceCard({required this.invoice, this.onTap, super.key});

  final CreditCardInvoiceModel invoice;

  /// Abre o cartão. Opcional porque o card também é usado só para exibir — e
  /// um `InkWell` sem destino é armadilha para quem toca.
  final VoidCallback? onTap;

  /// Dimensionada para o pior caso: barra de limite estourado mais os três
  /// itens que o backend manda, cada um com linha de parcela. Esse caso mede
  /// 305px; o resto é folga para diferença de fonte entre plataformas.
  ///
  /// Medida, e não estimada — o teste do pior caso em
  /// `invoice_carousel_test.dart` é quem avisa se ela ficar curta.
  static const alturaBase = 312.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final usage = invoice.limitUsage;

    return SizedBox(
      // Acompanha a fonte do sistema: quem aumenta o texto aumenta junto o
      // espaço, senão a altura fixa vira estouro na primeira configuração de
      // acessibilidade.
      height: MediaQuery.textScalerOf(context).scale(alturaBase),
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: onTap,
          // O raio acompanha o do Card, senão o respingo do toque escapa pelos
          // cantos.
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.credit_card,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // `label` já vem pronto do backend: "Nubank ••••4321".
                          Text(
                            invoice.label,
                            style: theme.textTheme.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Vence em ${IsoDate.label(invoice.dueDate)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      Money.format(invoice.totalCents),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              if (usage != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: _LimitUsage(
                    usage: usage,
                    limitCents: invoice.limitCents!,
                  ),
                ),
              const Divider(height: 1),
              if (invoice.items.isEmpty)
                // Centralizado no que sobra, e não colado no divisor: com altura
                // fixa a sobra existe de qualquer jeito, e o aviso no meio dela
                // parece escolha em vez de card pela metade.
                Expanded(
                  child: Center(
                    child: Text(
                      'Nenhum gasto registrado',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              else
                // A lista é a parte elástica do card, e é de propósito: com
                // fonte muito ampliada o conteúdo cresce mais rápido que a
                // altura — o `ListTile` parte de um mínimo e depois dispara —
                // e aqui isso vira "mostra os itens que couberem", não listra
                // amarela. O card é prévia; a fatura inteira está na tela do
                // cartão, a um toque.
                Flexible(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 8),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      for (final item in invoice.items)
                        LineItemTile(item: item, maxLines: 1),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LimitUsage extends StatelessWidget {
  const _LimitUsage({required this.usage, required this.limitCents});

  /// 0 a 1, mas pode passar de 1 — a fatura pode estourar o limite.
  final double usage;
  final int limitCents;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overLimit = usage > 1;

    final color = switch (usage) {
      > 1 => theme.colorScheme.error,
      > 0.8 => theme.appColors.warning,
      _ => theme.colorScheme.primary,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: usage.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          overLimit
              ? 'Acima do limite de ${Money.format(limitCents)}'
              : '${(usage * 100).toStringAsFixed(0)}% do limite de ${Money.format(limitCents)}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: overLimit
                ? theme.colorScheme.error
                : theme.colorScheme.onSurfaceVariant,
          ),
          // Uma linha, como todo texto deste card: com altura fixa, um rótulo
          // que quebra em duas rouba a linha de um item.
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
