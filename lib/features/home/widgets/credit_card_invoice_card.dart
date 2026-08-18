import 'package:flutter/material.dart';

import '../../../core/utils/money.dart';
import '../../../data/models/credit_card_invoice_model.dart';
import 'line_item_tile.dart';

/// A fatura de um cartão no mês: total, vencimento, uso do limite e os itens.
class CreditCardInvoiceCard extends StatelessWidget {
  const CreditCardInvoiceCard({required this.invoice, super.key});

  final CreditCardInvoiceModel invoice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final usage = invoice.limitUsage;

    return Card(
      margin: EdgeInsets.zero,
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
                      Text(invoice.label, style: theme.textTheme.titleSmall),
                      const SizedBox(height: 2),
                      Text(
                        'Vence em ${_formatDueDate(invoice.dueDate)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  Money.format(invoice.totalCents),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          if (usage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _LimitUsage(usage: usage, limitCents: invoice.limitCents!),
            ),
          if (invoice.items.isNotEmpty) ...[
            const Divider(height: 1),
            for (final item in invoice.items) LineItemTile(item: item),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  /// `2026-08-17` → `17/08`. Formatado por corte de string, sem `DateTime`, pela
  /// mesma razão da competência: nada de fuso no caminho.
  static String _formatDueDate(String isoDate) {
    if (isoDate.length != 10) return isoDate;
    return '${isoDate.substring(8, 10)}/${isoDate.substring(5, 7)}';
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
      > 0.8 => Colors.orange,
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
        ),
      ],
    );
  }
}
