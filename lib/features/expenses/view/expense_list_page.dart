import 'package:flutter/material.dart';
import 'package:se_controle_ai/core/shared/widgets/month_selector_widget.dart';
import 'package:se_controle_ai/core/theme/app_theme.dart';
import 'package:se_controle_ai/data/services/navigation_service.dart';
import 'package:signals/signals_flutter.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../core/di/injector.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/shared/view_state.dart';
import '../../../core/shared/widgets/failure_card_widget.dart';
import '../../../core/utils/expense_utils.dart';
import '../../../core/utils/money_utils.dart';
import '../../../core/utils/month_utils.dart';
import '../../../data/enums/payment_method.dart';
import '../../../data/models/expense_model.dart';
import '../../../data/services/selected_month_service.dart';
import '../controller/expense_controller.dart';
import '../widgets/expense_list_empty_widget.dart';
import '../widgets/expense_tile.dart';

class ExpenseListPage extends StatefulWidget {
  const ExpenseListPage({this.paymentMethod, super.key});

  final PaymentMethod? paymentMethod;

  @override
  State<ExpenseListPage> createState() => _ExpenseListPageState();
}

class _ExpenseListPageState extends State<ExpenseListPage> {
  final _controller = getIt<ExpenseController>();
  final _nav = getIt<NavigationService>();

  final _selectedMonth = getIt<SelectedMonthService>();

  @override
  void initState() {
    super.initState();
    _controller.start(widget.paymentMethod);
  }

  @override
  void dispose() {
    getIt.resetLazySingleton<ExpenseController>();
    super.dispose();
  }

  String get _title => switch (widget.paymentMethod) {
    null => 'Gastos',
    PaymentMethod.debit => 'Gastos no dinheiro',
    PaymentMethod.creditCard => 'Gastos no cartão',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title), centerTitle: true),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _nav.pushNamed(AppRoutes.expenseForm),
        icon: const Icon(Icons.add),
        label: const Text('Novo gasto'),
      ),
      body: RefreshIndicator.adaptive(
        onRefresh: () => _controller.refresh(),
        child: CustomScrollView(
          slivers: [
            SignalBuilder(
              builder: (context) {
                final state = _controller.state.value;
                return switch (state) {
                  Loading() => _ExpenseList.skeleton(),
                  Loaded(:final data) => _ExpenseList(
                    expenses: data,
                    month: _selectedMonth.month.value,
                    onOpen: (expense) =>
                        _nav.pushNamed(AppRoutes.expenseDetail, extra: expense),
                  ),
                  Failed(:final failure) => SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const .all(16),
                        child: FailureCardWidget(
                          failure: failure,
                          onRetry: _controller.refresh,
                        ),
                      ),
                    ),
                  ),
                };
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpenseList extends StatelessWidget {
  final List<ExpenseModel> expenses;
  final String month;
  final bool loading;

  final void Function(ExpenseModel expense)? onOpen;

  const _ExpenseList({
    required this.expenses,
    required this.month,
    required this.onOpen,
  }) : loading = false;

  const _ExpenseList.skeleton()
    : expenses = const [],
      onOpen = null,
      month = '',
      loading = true;

  int get _monthTotalCents => expenses.fold(0, _addAmountIn);

  int get _recurringTotalCents => expenses
      .where((expense) => expense.endMonth == null)
      .fold(0, _addAmountIn);

  int _addAmountIn(int total, ExpenseModel expense) =>
      total + (ExpenseUtils.amountCentsIn(expense, month) ?? 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final paddingBottom = MediaQuery.paddingOf(context).bottom;
    final monthTotal = _monthTotalCents;
    final recurring = _recurringTotalCents;
    final secondary = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return SliverMainAxisGroup(
      slivers: [
        SliverPadding(
          padding: .all(24),
          sliver: SliverToBoxAdapter(
            child: Skeletonizer(
              enabled: loading,
              child: Column(
                spacing: 4,
                children: [
                  Row(
                    mainAxisAlignment: .spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          'Sai em ${MonthUtils.label(month)}',
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      Text(
                        MoneyUtils.format(monthTotal),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                  Visibility(
                    visible: recurring != monthTotal,
                    child: Row(
                      mainAxisAlignment: .spaceBetween,
                      children: [
                        Text('Recorrente por mês', style: secondary),
                        Text(MoneyUtils.format(recurring), style: secondary),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        DecoratedSliver(
          decoration: BoxDecoration(
            color: theme.appColors.card,
            boxShadow: [
              BoxShadow(
                color: theme.appColors.cardShadow,
                spreadRadius: 0,
                blurRadius: 40,
                offset: const Offset(0, 1),
              ),
            ],
            borderRadius: .vertical(top: .circular(24)),
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
                padding: .only(bottom: 80 + paddingBottom),
                sliver: SliverVisibility(
                  visible: !loading,
                  replacementSliver: SliverList.separated(
                    itemCount: 3,
                    itemBuilder: (_, _) =>
                        const Skeletonizer(child: ExpenseTile.skeleton()),
                    separatorBuilder: (_, _) => const Divider(),
                  ),
                  sliver: expenses.isEmpty
                      ? SliverPadding(
                          padding: const .symmetric(horizontal: 24),
                          sliver: SliverFillRemaining(
                            fillOverscroll: true,
                            hasScrollBody: false,
                            child: ExpenseListEmptyWidget(month: month),
                          ),
                        )
                      : SliverList.separated(
                          itemCount: expenses.length,
                          separatorBuilder: (context, index) => const Divider(),
                          itemBuilder: (context, index) {
                            final expense = expenses[index];
                            return ExpenseTile(
                              expense: expense,
                              monthSelected: month,
                              onTap: () => onOpen?.call(expense),
                            );
                          },
                        ),
                ),
              ),
              SliverFillRemaining(
                fillOverscroll: true,
                hasScrollBody: false,
                child: SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
