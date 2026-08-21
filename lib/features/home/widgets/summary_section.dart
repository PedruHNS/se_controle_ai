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
    this.maxItems,
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

  /// Teto de linhas exibidas. Quando nulo, mostra todas.
  ///
  /// O total do cabeçalho continua sendo o do mês inteiro, não a soma do que
  /// aparece — é o número que importa, e recalculá-lo sobre a fatia truncada
  /// faria a seção contradizer o card de saldo logo acima. Por isso o rodapé
  /// diz quantas linhas ficaram de fora: sem ele, os itens não somam o total e
  /// a diferença parece erro de conta.
  final int? maxItems;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (items.isEmpty && emptyMessage == null) {
      return const SizedBox.shrink();
    }

    final limit = maxItems;
    final visible = limit == null || items.length <= limit
        ? items
        : items.take(limit).toList();
    final hidden = items.length - visible.length;

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
            for (final item in visible) LineItemTile(item: item),
            if (hidden > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Text(
                  hidden == 1
                      ? 'e mais 1 lançamento'
                      : 'e mais $hidden lançamentos',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}
