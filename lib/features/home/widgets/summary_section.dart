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
    this.onTap,
    super.key,
  });

  final String title;
  final IconData icon;
  final List<SummaryLineItemModel> items;
  final int totalCents;

  /// Quando nulo e a lista está vazia, a seção não é renderizada. Passe um texto
  /// para mostrar o vazio explicitamente.
  final String? emptyMessage;

  /// Leva para a tela de cadastro do assunto da seção. Quando nulo, o cabeçalho
  /// é só um rótulo — é o caso do débito, que ainda não tem tela própria.
  final VoidCallback? onTap;

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
          InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(title, style: theme.textTheme.titleSmall),
                  ),
                  Text(
                    Money.format(totalCents),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  // A seta aparece só quando há para onde ir — sem ela o toque
                  // no cabeçalho seria uma descoberta por acidente.
                  if (onTap != null) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ],
              ),
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
