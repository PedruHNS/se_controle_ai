import 'package:flutter/material.dart';
import 'package:se_controle_ai/core/shared/widgets/month_selector_widget.dart';
import 'package:se_controle_ai/features/credit_cards/widgets/expense_empty_widget.dart';
import 'package:se_controle_ai/features/credit_cards/widgets/invoice_card_widget.dart';
import 'package:signals/signals_flutter.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '../../../core/di/injector.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/shared/view_state.dart';
import '../../../core/shared/widgets/failure_card_widget.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/month_utils.dart';
import '../../../data/models/credit_card_bill_model.dart';
import '../../../data/models/expense_model.dart';
import '../../../data/services/navigation_service.dart';
import '../../expenses/widgets/expense_tile.dart';
import '../controller/credit_card_expenses_controller.dart';

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

          return switch (state) {
            Loading() => _CardExpenses.skeleton(
              onRefresh: () => _controller.refresh(id: widget.id),
            ),
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
          };
        },
      ),
    );
  }
}

class _CardExpenses extends StatelessWidget {
  final CreditCardBillModel view;
  final bool loading;
  final Future<void> Function() onRefresh;
  final void Function(ExpenseModel expense)? onOpen;

  const _CardExpenses({
    required this.view,
    required this.onRefresh,
    required this.onOpen,
  }) : loading = false;

  _CardExpenses.skeleton({required this.onRefresh})
    : view = CreditCardBillModel.skeleton(),
      onOpen = null,
      loading = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final paddingBottom = MediaQuery.paddingOf(context).bottom;

    return RefreshIndicator.adaptive(
      onRefresh: onRefresh,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Visibility(
              visible: !loading,
              replacement: const Skeletonizer(
                child: InvoiceCardWidget.skeleton(),
              ),
              child: InvoiceCardWidget(card: view.card, month: view.month),
            ),
          ),

          DecoratedSliver(
            decoration: BoxDecoration(
              color: theme.appColors.card,
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).appColors.cardShadow,
                  spreadRadius: 0,
                  blurRadius: 40,
                  offset: const Offset(0, 1),
                ),
              ],

              borderRadius: .vertical(top: .circular(20)),
            ),
            sliver: SliverMainAxisGroup(
              slivers: [
                SliverPadding(padding: .symmetric(vertical: 10)),
                PinnedHeaderSliver(
                  child: Material(
                    color: theme.appColors.card,
                    child: MonthSelectorWidget(),
                  ),
                ),

                SliverPadding(
                  padding: .fromLTRB(10, 12, 10, 80 + paddingBottom),
                  sliver: SliverVisibility(
                    visible: !loading,
                    sliver: view.expenses.isEmpty
                        ? SliverPadding(
                            padding: const .symmetric(horizontal: 24),
                            sliver: SliverFillRemaining(
                              hasScrollBody: false,
                              child: ExpenseEmptyWidget(
                                title:
                                    'Nenhum gasto deste cartão é cobrado em '
                                    '${MonthUtils.label(view.month)}. Trocar o mês no topo mostra '
                                    'as outras faturas.',
                              ),
                            ),
                          )
                        : SliverList.separated(
                            itemCount: view.expenses.length,
                            itemBuilder: (context, i) => ExpenseTile(
                              expense: view.expenses[i],
                              month: view.month,
                              onTap: () => onOpen?.call(view.expenses[i]),
                            ),
                            separatorBuilder: (context, index) =>
                                const Divider(),
                          ),
                    replacementSliver: SliverList.separated(
                      itemCount: 2,
                      itemBuilder: (_, _) =>
                          const Skeletonizer(child: ExpenseTile.skeleton()),
                      separatorBuilder: (_, _) => const Divider(),
                    ),
                  ),
                ),

                // if (view.expenses.isEmpty)
                //   SliverPadding(
                //     padding: const .symmetric(horizontal: 24),
                //     sliver: SliverFillRemaining(
                //       hasScrollBody: false,
                //       child: ExpenseEmptyWidget(
                //         title:
                //             'Nenhum gasto deste cartão é cobrado em '
                //             '${MonthUtils.label(view.month)}. Trocar o mês no topo mostra '
                //             'as outras faturas.',
                //       ),
                //     ),
                //   ),
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
