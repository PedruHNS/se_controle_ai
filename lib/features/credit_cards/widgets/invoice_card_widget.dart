import 'package:flutter/material.dart';
import 'package:se_controle_ai/core/utils/money_utils.dart';
import 'package:se_controle_ai/core/utils/month_utils.dart';
import 'package:se_controle_ai/data/models/credit_card_model.dart';

class InvoiceCardWidget extends StatelessWidget {
  const InvoiceCardWidget({super.key, required this.card, required this.month});

  /// O mesmo desenho com uma fatura de mentira dentro, para o `Skeletonizer`
  /// medir — `Skeletonizer(child: InvoiceCardWidget.skeleton())`.
  ///
  /// Os valores são plausíveis de propósito: é a largura de cada texto que vira
  /// a barra cinza, e zero ou string vazia dariam um esqueleto menor que o card
  /// que vai chegar. O limite entra preenchido pelo mesmo motivo — é ele que
  /// põe a barra de progresso na tela, e sem ele o esqueleto teria uma altura e
  /// o card, outra.
  const InvoiceCardWidget.skeleton({super.key})
    : card = const CreditCardModel(
        id: '',
        name: 'Cartão',
        label: 'Cartão',
        lastDigits: null,
        closingDay: 30,
        dueDay: 10,
        limitCents: 500000,
        dueDate: null,
        totalCents: 128790,
      ),
      month = '2026-01';

  final CreditCardModel card;
  final String month;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        spacing: 8,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Fatura de ${MonthUtils.label(month)}',
            style: theme.textTheme.titleSmall,
          ),

          Text(
            MoneyUtils.format(card.totalCents!),
            style: theme.textTheme.headlineMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),

          Visibility(
            visible: card.limitCents != null,
            child: Column(
              spacing: 10,
              children: [
                Padding(
                  padding: const .symmetric(horizontal: 10),
                  child: Row(
                    mainAxisAlignment: .spaceBetween,
                    children: [
                      Text(
                        MoneyUtils.format(card.totalCents!),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        MoneyUtils.format(card.limitCents!),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                LinearProgressIndicator(
                  // Acima do limite a barra para em 100%: passar disso quebraria
                  // o desenho, e o número ao lado já conta a história inteira.
                  value: (card.totalCents! / card.limitCents!)
                      .clamp(0, 1)
                      .toDouble(),
                ),
              ],
            ),
          ),

          Divider(height: 20),
          Padding(
            padding: const .symmetric(horizontal: 10),
            child: Row(
              mainAxisAlignment: .spaceBetween,
              children: [
                Text(
                  'Fecha dia ${card.closingDay}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  ' vence dia ${card.dueDay}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
