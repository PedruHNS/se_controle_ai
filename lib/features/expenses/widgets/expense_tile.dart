import 'package:flutter/material.dart';

import '../../../core/utils/iso_date_utils.dart';
import '../../../core/utils/money_utils.dart';
import '../../../core/utils/tag_color_utils.dart';
import '../../../data/enums/expense_type.dart';
import '../../../data/enums/payment_method.dart';
import '../../../data/models/expense_model.dart';
import '../../../data/models/tag_model.dart';

/// Uma linha da lista de gastos: descrição, categoria, período, dia da compra
/// e o valor vigente.
///
/// **Sem fundo próprio.** A lista de gastos desenha sobre o fundo da tela, mas
/// a fatura do cartão desenha dentro de um painel que já é `appColors.card`:
/// um card com sombra aqui sumiria lá, card sobre card da mesma cor. O que
/// separa uma linha da outra é o espaçamento de quem monta a lista.
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

  /// O selo do canto direito, e se ele é o de destaque.
  ///
  /// A ordem importa: a parcela do mês manda em cima de "Encerrado", porque
  /// todo parcelado tem fim por natureza e dizer que acabou não informaria
  /// nada.
  (String texto, bool destaque)? get _badge {
    final parcela = expense.installmentLabelIn(monthSelected);
    if (parcela != null) return (parcela, true);
    if (expense.endedBefore(monthSelected)) return ('Encerrado', false);
    if (expense.isSingleMonth) return ('Mês único', false);
    return null;
  }

  /// O valor no mês exibido. Um gasto encerrado ou que só começa no mês que vem
  /// não tem valor **neste** mês — aí a lista mostra o da vigência mais
  /// recente, que é o último valor que ele teve ou terá.
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

          if (badge case (final texto, final destaque)?)
            _Selo(texto: texto, destaque: destaque),
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

class _Selo extends StatelessWidget {
  const _Selo({required this.texto, required this.destaque});

  final String texto;

  /// A parcela vem em destaque; "Encerrado" e "Mês único", em cinza. A parcela
  /// muda o que a pessoa lê no valor ao lado — "são R$ 300, e faltam sete" —,
  /// enquanto as outras duas são só contexto do que já está escrito no período.
  final bool destaque;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const .symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: destaque
            ? scheme.secondaryContainer
            : scheme.surfaceContainerHighest,
        borderRadius: .circular(6),
      ),
      child: Text(
        texto,
        style: theme.textTheme.labelSmall?.copyWith(
          color: destaque
              ? scheme.onSecondaryContainer
              : scheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
