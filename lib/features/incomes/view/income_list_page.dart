import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:se_controle_ai/core/shared/widgets/month_selector_widget.dart';
import 'package:se_controle_ai/core/theme/app_theme.dart';
import 'package:se_controle_ai/data/services/navigation_service.dart';
import 'package:signals/signals_flutter.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../core/di/injector.dart';
import '../../../data/services/selected_month_service.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/shared/view_state.dart';
import '../../../core/shared/widgets/failure_card_widget.dart';
import '../../../core/utils/amount_version_utils.dart';
import '../../../core/utils/money_utils.dart';
import '../../../core/utils/month_utils.dart';
import '../../../data/models/income_model.dart';
import '../controller/income_controller.dart';
import '../widgets/income_empty_widget.dart';
import '../widgets/income_tile.dart';

/// Lista de ganhos — a porta de entrada do CRUD.
class IncomeListPage extends StatefulWidget {
  const IncomeListPage({super.key});

  @override
  State<IncomeListPage> createState() => _IncomeListPageState();
}

class _IncomeListPageState extends State<IncomeListPage> {
  final _controller = getIt<IncomeController>();
  final _nav = getIt<NavigationService>();

  final _selectedMonth = getIt<SelectedMonthService>();

  @override
  void dispose() {
    getIt.resetLazySingleton<IncomeController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ganhos'), centerTitle: true),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.pushNamed(AppRoutes.incomeForm),
        icon: const Icon(Icons.add),
        label: const Text('Novo ganho'),
      ),
      body: RefreshIndicator.adaptive(
        onRefresh: () => _controller.refresh(),
        child: CustomScrollView(
          slivers: [
            SignalBuilder(
              builder: (context) {
                final state = _controller.state.value;
                return switch (state) {
                  Loading() => _IncomeList.skeleton(),
                  Loaded(:final data) => _IncomeList(
                    incomes: data,
                    month: _selectedMonth.month.value,
                    onOpen: (income) => _nav.pushNamed(
                      AppRoutes.incomeDetail,
                      pathParameters: {RouteParams.id: income.id},
                    ),
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

class _IncomeList extends StatelessWidget {
  final List<IncomeModel> incomes;
  final String month;
  final bool loading;

  final void Function(IncomeModel income)? onOpen;

  const _IncomeList({
    required this.incomes,
    required this.month,
    required this.onOpen,
  }) : loading = false;

  const _IncomeList.skeleton()
    : incomes = const [],
      onOpen = null,
      month = '',
      loading = true;

  int get _monthTotalCents => incomes.fold(0, _addAmountIn);

  int _addAmountIn(int total, IncomeModel income) =>
      total + (AmountVersionUtils.amountCentsIn(income.history, month) ?? 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SliverMainAxisGroup(
      slivers: [
        SliverPadding(
          padding: .all(24),
          sliver: SliverToBoxAdapter(
            child: Skeletonizer(
              enabled: loading,
              child: Row(
                mainAxisAlignment: .spaceBetween,
                children: [
                  Text(
                    'Entra em ${MonthUtils.label(month)}',
                    style: theme.textTheme.titleSmall,
                  ),
                  Text(
                    MoneyUtils.format(_monthTotalCents),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
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
                color: Theme.of(context).appColors.cardShadow,
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
              SliverVisibility(
                visible: !loading,
                replacementSliver: SliverList.separated(
                  itemCount: 3,
                  itemBuilder: (_, _) =>
                      const Skeletonizer(child: IncomeTile.skeleton()),
                  separatorBuilder: (_, _) => const Divider(),
                ),
                sliver: incomes.isEmpty
                    ? SliverPadding(
                        padding: const .symmetric(horizontal: 24),
                        sliver: SliverFillRemaining(
                          fillOverscroll: true,
                          hasScrollBody: false,
                          child: IncomeEmptyWidget(month: month),
                        ),
                      )
                    : SliverList.separated(
                        itemCount: incomes.length,
                        separatorBuilder: (context, index) => const Divider(),
                        itemBuilder: (context, index) {
                          final income = incomes[index];
                          return IncomeTile(
                            income: income,
                            month: month,
                            onTap: () => onOpen?.call(income),
                          );
                        },
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
