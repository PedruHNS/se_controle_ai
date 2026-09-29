import 'package:flutter/material.dart';

import '../../../core/utils/iso_date_utils.dart';
import '../../../core/utils/money_utils.dart';
import '../../../core/utils/month_utils.dart';
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
  final String month;
  final VoidCallback? onTap;

  const ExpenseTile({
    required this.expense,
    required this.month,
    this.onTap,
    super.key,
  });

  /// O mesmo desenho com um gasto de mentira dentro, para o `Skeletonizer`
  /// medir — `Skeletonizer(child: ExpenseTile.skeleton())`.
  ///
  /// Os valores são plausíveis de propósito: é a largura de cada texto que
  /// vira a barra cinza, e string vazia daria um esqueleto do tamanho errado.
  /// O gasto nasce sem parcela, sem fim e sem `onTap` — assim o selo não
  /// aparece e a linha não é tocável enquanto carrega.
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
      month = '2026-01',
      onTap = null;

  /// O desenho diz **como se paga**; a cor, **de que categoria é**. São duas
  /// perguntas diferentes, e cada uma tem seu canal.
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
    final parcela = expense.installmentLabelIn(month);
    if (parcela != null) return (parcela, true);
    if (expense.endedBefore(month)) return ('Encerrado', false);
    if (expense.isSingleMonth) return ('Mês único', false);
    return null;
  }

  /// O valor no mês exibido. Um gasto encerrado ou que só começa no mês que vem
  /// não tem valor **neste** mês — aí a lista mostra o da vigência mais
  /// recente, que é o último valor que ele teve ou terá.
  int? get _amountCents =>
      expense.amountCentsIn(month) ?? expense.latestAmountCents;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amount = _amountCents;
    final badge = _badge;

    // Gasto que acabou antes do mês exibido continua na lista, mas o dinheiro
    // dele não sai desta competência: em vermelho ele cobraria uma despesa que
    // já não existe.
    final encerrado = expense.endedBefore(month);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: .circular(12),
        child: Padding(
          padding: const .symmetric(horizontal: 16, vertical: 12),
          child: Row(
            spacing: 12,
            children: [
              _Icone(
                icon: _icon,
                cor: TagColorUtils.parse(expense.tag.color),
                apagado: encerrado,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment: .start,
                  mainAxisSize: .min,
                  spacing: 2,
                  children: [
                    Text(
                      expense.description,
                      maxLines: 1,
                      overflow: .ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),

                    // A tag vem colada no ícone que a pinta, e o período logo
                    // depois: é ele que diferencia um aluguel de um presente.
                    // A tag entra sempre, porque é ela que agrupa e é
                    // obrigatória (TAG-06).
                    Text(
                      [
                        expense.tag.name,

                        MonthUtils.periodLabel(
                          expense.startMonth,
                          expense.endMonth,
                        ),
                      ].join(' · '),
                      maxLines: 1,
                      overflow: .ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),

                    // O dia da compra (GFX-12) fica na sua própria linha, e não
                    // colado no período: são duas datas diferentes — "comprei
                    // no dia 30" e "sai da competência de outubro" — e juntá-las
                    // numa linha só faria parecer que uma corrige a outra.
                    //
                    // O verbo segue a data: gasto planejado tem dia no futuro, e
                    // dizer "compra em" sobre o que não aconteceu seria
                    // afirmação falsa.
                    if (expense.spentAt case final spentAt?)
                      Padding(
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
                                '${IsoDateUtils.isFuture(spentAt) ? 'Previsto para' : 'Compra em'} '
                                '${IsoDateUtils.fullLabel(spentAt)}',
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
                  ],
                ),
              ),

              Column(
                mainAxisAlignment: .center,
                crossAxisAlignment: .end,
                spacing: 4,
                children: [
                  Text(
                    amount == null ? '—' : MoneyUtils.format(amount),
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
            ],
          ),
        ),
      ),
    );
  }
}

/// O quadrado colorido da esquerda.
///
/// A cor é a da tag — a mesma que pinta a bolinha na lista de tags e a barra do
/// dashboard —, e é ela que faz a categoria ser reconhecida antes de qualquer
/// leitura.
class _Icone extends StatelessWidget {
  const _Icone({required this.icon, required this.cor, required this.apagado});

  final IconData icon;
  final Color cor;

  final bool apagado;

  Color _legivel(Color fundo, Brightness brightness) {
    final passo = brightness == Brightness.light ? -0.04 : 0.04;
    var hsl = HSLColor.fromColor(cor);

    // O teto de passos existe para o laço não depender só do contraste: numa
    // cor que nunca chega aos 4,5:1, o melhor que deu é melhor que travar.
    for (var i = 0; i < 25; i++) {
      final atual = hsl.toColor();
      if (_contraste(atual, fundo) >= 4.5) return atual;

      final lightness = (hsl.lightness + passo).clamp(0.0, 1.0);
      if (lightness == hsl.lightness) return atual;
      hsl = hsl.withLightness(lightness);
    }

    return hsl.toColor();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final apagada = theme.colorScheme.onSurfaceVariant;

    // O fundo é a cor **como foi escolhida** e o ícone é a versão empurrada
    // para o contraste: pintar os dois com a corrigida deixaria marrom o
    // quadrado de uma tag amarela, e é o quadrado que guarda o matiz.
    final fundo = apagado ? apagada : cor;
    final corDoIcone = apagado
        ? apagada
        : _legivel(theme.colorScheme.surface, theme.brightness);

    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fundo.withValues(alpha: 0.16),
        borderRadius: .circular(12),
      ),
      child: Icon(icon, size: 20, color: corDoIcone),
    );
  }
}

/// O selo abaixo do valor: `3/10`, `Encerrado`, `Mês único`.
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

/// A razão de contraste do WCAG entre duas cores opacas: 1 é a mesma cor, 21 é
/// preto contra branco.
double _contraste(Color a, Color b) {
  final primeira = a.computeLuminance();
  final segunda = b.computeLuminance();
  final (maior, menor) = primeira > segunda
      ? (primeira, segunda)
      : (segunda, primeira);

  return (maior + 0.05) / (menor + 0.05);
}
