import 'package:flutter/material.dart';

import '../../../core/utils/money.dart';
import '../../../data/models/summary_line_item_model.dart';
import 'line_item_tile.dart';

/// Bloco "título + total + itens". Usado para ganhos e para gastos no débito,
/// que têm a mesma estrutura visual.
class SummarySection extends StatelessWidget {
  const SummarySection({
    required this.title,
    required this.icon,
    required this.items,
    required this.totalCents,
    this.emptyMessage,
    super.key,
  });

  final String title;
  final IconData icon;
  final List<SummaryLineItemModel> items;
  final int totalCents;

  /// Quando nulo e a lista está vazia, a seção não é renderizada. Passe um texto
  /// para mostrar o vazio explicitamente.
  final String? emptyMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (items.isEmpty && emptyMessage == null) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(child: Text(title, style: theme.textTheme.titleSmall)),
                Text(
                  Money.format(totalCents),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                emptyMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else ...[
            const Divider(height: 1),
            for (final item in items) LineItemTile(item: item),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}
