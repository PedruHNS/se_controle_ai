import 'package:flutter/material.dart';
import 'package:se_controle_ai/core/shared/widgets/custom_box_shadow_widget.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/iso_date.dart';
import '../../../core/utils/money.dart';
import '../../../data/models/credit_card_model.dart';

/// Uma linha da lista de cartões: o rótulo, os dois dias e o limite.
class CreditCardWidget extends StatelessWidget {
  final CreditCardModel card;
  final void Function()? onTap;
  final void Function()? onEdit;
  final void Function()? onDelete;

  const CreditCardWidget({
    required this.card,
    this.onTap,
    this.onEdit,
    this.onDelete,
    super.key,
  });

  CreditCardWidget.esqueleton({super.key})
    : card = CreditCardModel(
        id: '',
        name: '',
        label: '',
        lastDigits: null,
        closingDay: 0,
        dueDay: 0,
        limitCents: null,
        dueDate: null,
        totalCents: null,
      ),
      onEdit = null,
      onDelete = null,
      onTap = null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final limit = card.limitCents ?? 0;
    final totalCents = card.totalCents ?? 0;
    final remainingLimit = limit - totalCents;

    return CustomBoxShadowWidget(
      child: Material(
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Ink(
            padding: .all(18),
            decoration: BoxDecoration(
              color: theme.appColors.card,
              borderRadius: BorderRadius.circular(10),
            ),

            child: Column(
              crossAxisAlignment: .start,

              children: [
                Row(
                  mainAxisAlignment: .spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        card.name,
                        style: theme.textTheme.titleSmall,
                        overflow: .ellipsis,
                      ),
                    ),
                    _MenuDeAcoes(onEdit: onEdit, onDelete: onDelete),
                  ],
                ),

                Padding(
                  padding: .fromLTRB(8, 12, 0, 12),
                  child: Column(
                    crossAxisAlignment: .start,
                    children: [
                      Text(
                        'Limite',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        Money.formatCompact(remainingLimit),
                        style: theme.textTheme.titleLarge,
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  child: Column(
                    spacing: 8,
                    children: [
                      Row(
                        mainAxisAlignment: .spaceBetween,
                        children: [
                          Text(
                            Money.formatCompact(totalCents),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            Money.formatCompact(limit),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      LinearProgressIndicator(
                        value: (totalCents / limit).clamp(0, 1).toDouble(),
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Divider(),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
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
                        'Vence dia ${IsoDate.label(card.dueDay.toString())}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _Acao { editar, excluir }

class _MenuDeAcoes extends StatelessWidget {
  const _MenuDeAcoes({required this.onEdit, required this.onDelete});

  final void Function()? onEdit;
  final void Function()? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopupMenuButton<_Acao>(
      icon: const Icon(Icons.more_vert),
      tooltip: 'Mais opções',
      padding: .zero,
      style: IconButton.styleFrom(
        padding: .zero,
        minimumSize: const Size(24, 24),
        tapTargetSize: .shrinkWrap,
      ),
      enabled: onEdit != null || onDelete != null,
      onSelected: (acao) {
        switch (acao) {
          case .editar:
            onEdit?.call();
          case .excluir:
            onDelete?.call();
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: .editar,
          child: ListTile(
            contentPadding: .zero,
            leading: Icon(Icons.edit_outlined),
            title: Text('Editar'),
          ),
        ),
        PopupMenuItem(
          value: .excluir,
          child: ListTile(
            contentPadding: .zero,
            iconColor: theme.colorScheme.error,
            textColor: theme.colorScheme.error,
            leading: Icon(Icons.delete_outline),
            title: Text('Excluir'),
          ),
        ),
      ],
    );
  }
}
