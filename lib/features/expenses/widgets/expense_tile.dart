import 'package:flutter/material.dart';

import '../../../core/utils/iso_date_utils.dart';
import '../../../core/utils/money_utils.dart';
import '../../../core/utils/tag_color_utils.dart';
import '../../../data/enums/expense_type.dart';
import '../../../data/enums/payment_method.dart';
import '../../../data/models/expense_model.dart';
import '../../../data/models/tag_model.dart';

class ExpenseTile extends StatelessWidget {
  final ExpenseModel expense;
  final String monthSelected;
  final VoidCallback? onTap;

  const ExpenseTile({
    required this.expense,
    required this.monthSelected,
    this.onTap,
    super.key,
  });

  const ExpenseTile.skeleton({super.key})
    : expense = const ExpenseModel(
        id: '',
        description: 'Assinatura de streaming',
        tag: TagModel(id: '', name: 'Categoria', color: '#78909C'),
        notes: null,
        type: ExpenseType.fixed,
        paymentMethod: PaymentMethod.creditCard,
        creditCardId: null,
        recurring: true,
        spentAt: '2026-01-10',
        startMonth: '2026-01',
        endMonth: null,
        amountCents: 12990,
        totalCents: null,
        installmentsCount: null,
        installmentLabel: null,
        history: [],
        installments: [],
      ),
      monthSelected = '2026-01',
      onTap = null;

  IconData get _icon {
    if (expense.isInstallment) return Icons.view_week_outlined;
    if (expense.onCreditCard) return Icons.credit_card;
    return Icons.payments_outlined;
  }

  String get _badge {
    final parcela = expense.installmentLabelIn(monthSelected);
    if (parcela != null) return parcela;
    if (expense.endedBefore(monthSelected)) return 'Encerrado';
    return 'Mês único';
  }

  int? get _amountCents =>
      expense.amountCentsIn(monthSelected) ?? expense.latestAmountCents;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amount = _amountCents;
    final badge = _badge;

    final encerrado = expense.endedBefore(monthSelected);

    return ListTile(
      onTap: onTap,
      leading: _IconCustom(
        icon: _icon,
        color: TagColorUtils.parse(expense.tag.color),
      ),
      title: Text(
        expense.description,
        maxLines: 1,
        overflow: .ellipsis,
        style: theme.textTheme.titleSmall,
      ),
      subtitle: Column(
        crossAxisAlignment: .start,
        children: [
          Text(
            expense.tag.name,
            maxLines: 1,
            overflow: .ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),

          Visibility(
            visible: expense.spentAt != null,
            child: Padding(
              padding: const .only(top: 2),
              child: Row(
                spacing: 4,
                children: [
                  Icon(
                    Icons.event_outlined,
                    size: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  Flexible(
                    child: Text(
                      '${IsoDateUtils.isFuture(expense.spentAt ?? '') ? 'Previsto para' : 'Compra em'} '
                      '${IsoDateUtils.fullLabel(expense.spentAt ?? '')}',
                      maxLines: 1,
                      overflow: .ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      trailing: Column(
        crossAxisAlignment: .end,
        spacing: 4,
        children: [
          Text(
            MoneyUtils.format(amount ?? 0),
            style: theme.textTheme.titleMedium?.copyWith(
              color: encerrado
                  ? theme.colorScheme.onSurfaceVariant
                  : theme.colorScheme.error,
            ),
          ),
          _Badge(text: badge),
        ],
      ),
    );
  }
}

class _IconCustom extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _IconCustom({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      alignment: .center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: .circular(12),
      ),
      child: Icon(icon, size: 20, color: color),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;

  const _Badge({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const .symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: .circular(6),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
