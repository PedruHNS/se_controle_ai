import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';

import '../../../core/di/injector.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/shared/view_state.dart';
import '../../../core/shared/widgets/failure_card_widget.dart';
import '../../../core/shared/widgets/state_transition.dart';
import '../../../core/utils/iso_date_utils.dart';
import '../../../core/utils/money_utils.dart';
import '../../../core/utils/month_utils.dart';
import '../../../data/models/credit_card_bill_model.dart';
import '../../../data/models/credit_card_model.dart';
import '../../../data/models/expense_model.dart';
import '../../../data/services/navigation_service.dart';
import '../../expenses/widgets/expense_tile.dart';
import '../controller/credit_card_expenses_controller.dart';

/// Um cartão e o que foi lançado nele.
///
/// É a tela que a Fase 3 decidiu **não** ter — na época um cartão eram cinco
/// campos, e uma tela só de leitura para eles seria um passo a mais para chegar
/// ao mesmo formulário. O que mudou é que agora existe gasto no cartão, e essa
/// é a pergunta que a lista de cartões não responde: *o que eu lancei neste?*
/// A edição continua a um toque, agora pelo lápis da barra.
class CreditCardExpensesPage extends StatefulWidget {
  const CreditCardExpensesPage({required this.id, super.key});

  final String id;

  @override
  State<CreditCardExpensesPage> createState() => _CreditCardExpensesPageState();
}

class _CreditCardExpensesPageState extends State<CreditCardExpensesPage> {
  final _controller = getIt<CreditCardExpensesController>();
  final _nav = getIt<NavigationService>();

  @override
  void initState() {
    super.initState();
    _controller.start(widget.id);
  }

  @override
  void dispose() {
    getIt.resetLazySingleton<CreditCardExpensesController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: SignalBuilder(
          builder: (context) => Text(switch (_controller.state.value) {
            Loaded(data: final view) => view.card.label,
            _ => 'Cartão',
          }),
        ),
        centerTitle: true,
      ),
      body: SignalBuilder(
        builder: (context) {
          final state = _controller.state.value;

          return StateTransition(
            stateKey: state.runtimeType,
            child: switch (state) {
              Loading() => const Center(child: CircularProgressIndicator()),
              Failed(failure: final failure) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: FailureCardWidget(
                    failure: failure,
                    onRetry: () => _controller.refresh(id: widget.id),
                  ),
                ),
              ),
              Loaded(data: final view) => _CardExpenses(
                view: view,
                onRefresh: () => _controller.refresh(id: widget.id),
                onOpen: (expense) => _nav.pushNamed(
                  AppRoutes.expenseDetail,
                  pathParameters: {RouteParams.id: expense.id},
                ),
              ),
            },
          );
        },
      ),
    );
  }
}

class _CardExpenses extends StatelessWidget {
  const _CardExpenses({
    required this.view,
    required this.onRefresh,
    required this.onOpen,
  });

  final CreditCardBillModel view;
  final Future<void> Function() onRefresh;
  final void Function(ExpenseModel expense) onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return RefreshIndicator.adaptive(
      onRefresh: onRefresh,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _InvoiceCard(
              card: view.card,
              month: view.month,
              totalCents: view.totalCents,
            ),
          ),
          SliverVisibility(
            visible: view.expenses.isNotEmpty,
            replacementSliver: SliverToBoxAdapter(),
            sliver: SliverList.separated(
              itemCount: view.expenses.length,
              itemBuilder: (context, i) => ExpenseTile(
                expense: view.expenses[i],
                month: view.month,
                onTap: () => onOpen(view.expenses[i]),
              ),
              separatorBuilder: (context, index) => const SizedBox(height: 8),
            ),
          ),
        ],
      ),
    );
  }
}

// RefreshIndicator(

//           if (view.expenses.isEmpty)
//             Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
//               child: Column(
//                 children: [
//                   Icon(
//                     Icons.receipt_long_outlined,
//                     size: 48,
//                     color: theme.colorScheme.onSurfaceVariant,
//                   ),
//                   const SizedBox(height: 12),
//                   Text(
//                     'Nada nesta fatura',
//                     textAlign: TextAlign.center,
//                     style: theme.textTheme.titleMedium,
//                   ),
//                   const SizedBox(height: 4),
//                   Text(
//                     'Nenhum gasto deste cartão é cobrado em '
//                     '${MonthUtils.label(view.month)}. Trocar o mês no topo mostra '
//                     'as outras faturas.',
//                     textAlign: TextAlign.center,
//                     style: theme.textTheme.bodySmall?.copyWith(
//                       color: theme.colorScheme.onSurfaceVariant,
//                     ),
//                   ),
//                 ],
//               ),
//             )
//           else ...[
//             Padding(
//               padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
//               child: Text('Nesta fatura', style: theme.textTheme.titleSmall),
//             ),
//             // Só o que é cobrado na competência, e não tudo que já passou pelo
//             // cartão: o cabeçalho acima é a fatura de um mês, e listar embaixo
//             // dele um avulso encerrado meses atrás contradiz o total exibido.
//             for (final expense in view.expenses)
//               ExpenseTile(
//                 expense: expense,
//                 month: view.month,
//                 onTap: () => onOpen(expense),
//               ),
//           ],
//         ],
//       ),
//     );

/// O cabeçalho: quanto vem na fatura deste mês, quando ela vence, e quanto do
/// limite isso ocupa.
class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({
    required this.card,
    required this.month,
    required this.totalCents,
  });

  final CreditCardModel card;
  final String month;
  final int totalCents;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final limit = card.limitCents;
    final due = card.dueDate;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fatura de ${MonthUtils.label(month)}',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text(
              MoneyUtils.format(totalCents),
              style: theme.textTheme.headlineMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              due == null
                  ? 'Fecha dia ${card.closingDay} · vence dia ${card.dueDay}'
                  : 'Fecha dia ${card.closingDay} · vence ${IsoDateUtils.label(due)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (limit != null) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                // Acima do limite a barra para em 100%: passar disso quebraria
                // o desenho, e o número ao lado já conta a história inteira.
                value: (totalCents / limit).clamp(0, 1).toDouble(),
              ),
              const SizedBox(height: 6),
              Text(
                '${MoneyUtils.format(totalCents)} de ${MoneyUtils.format(limit)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
