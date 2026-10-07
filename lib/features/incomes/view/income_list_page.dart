import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:se_controle_ai/core/shared/widgets/month_selector_widget.dart';
import 'package:se_controle_ai/core/theme/app_theme.dart';
import 'package:se_controle_ai/data/services/navigation_service.dart';
import 'package:signals/signals_flutter.dart';

import '../../../core/di/injector.dart';
import '../../../data/services/selected_month_service.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/shared/view_state.dart';
import '../../../core/shared/widgets/empty_state_widget.dart';
import '../../../core/shared/widgets/failure_card_widget.dart';
import '../../../core/utils/amount_version_utils.dart';
import '../../../core/utils/money_utils.dart';
import '../../../core/utils/month_utils.dart';
import '../../../data/models/income_model.dart';
import '../controller/income_controller.dart';
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
      body: CustomScrollView(
        slivers: [
          SignalBuilder(
            builder: (context) => _IncomeList(
              state: _controller.state.value,
              month: _selectedMonth.month.value,
              onRetry: _controller.refresh,
              onOpen: (income) => _nav.pushNamed(
                AppRoutes.incomeDetail,
                pathParameters: {RouteParams.id: income.id},
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// O cabeçalho e o card com o seletor de mês ficam na tela em qualquer estado:
/// só o miolo do card troca. Se o seletor sumisse no carregamento, cada troca
/// de mês piscaria a tela inteira — e num mês sem ganho não haveria como sair.
class _IncomeList extends StatelessWidget {
  final ViewState<List<IncomeModel>> state;
  final String month;

  final Future<void> Function() onRetry;
  final void Function(IncomeModel income) onOpen;

  const _IncomeList({
    required this.state,
    required this.month,
    required this.onRetry,
    required this.onOpen,
  });

  List<IncomeModel> get incomes => switch (state) {
    Loaded(data: final incomes) => incomes,
    _ => const [],
  };

  int get _monthTotalCents => incomes.fold(0, _addAmountIn);

  int get _recurringTotalCents =>
      incomes.where((income) => income.endMonth == null).fold(0, _addAmountIn);

  int _addAmountIn(int total, IncomeModel income) =>
      total + (AmountVersionUtils.amountCentsIn(income.history, month) ?? 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: ListTile(
            title: Text(
              'Entra em ${MonthUtils.label(month)}',
              style: theme.textTheme.titleSmall,
            ),
            // Sem total enquanto carrega: R$ 0,00 ali seria mentira.
            trailing: state is Loaded
                ? Text(
                    MoneyUtils.format(_monthTotalCents),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  )
                : null,
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
              switch (state) {
                Loading() => const SliverToBoxAdapter(
                  child: Padding(
                    padding: .all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
                Failed(failure: final failure) => SliverToBoxAdapter(
                  child: Padding(
                    padding: const .all(16),
                    child: FailureCardWidget(
                      failure: failure,
                      onRetry: onRetry,
                    ),
                  ),
                ),
                Loaded(data: final incomes) when incomes.isEmpty =>
                  SliverFillRemaining(
                    hasScrollBody: true,
                    child: EmptyStateWidget(
                      icon: Icons.trending_up,
                      title: 'Nenhum ganho em ${MonthUtils.label(month)}',
                      message:
                          'Cadastre em "Novo ganho" ou veja outro mês no seletor.',
                    ),
                  ),
                Loaded(data: final incomes) => SliverList.separated(
                  itemCount: incomes.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final income = incomes[index];
                    return IncomeTile(
                      income: income,
                      month: month,
                      onTap: () => onOpen(income),
                    );
                  },
                ),
              },
            ],
          ),
        ),
      ],
    );

    // return ListView.separated(
    //   physics: const AlwaysScrollableScrollPhysics(),
    //   // Espaço no fim para o FAB não cobrir o último item.
    //   padding: const EdgeInsets.only(bottom: 88),
    //   itemCount: incomes.length,
    //   separatorBuilder: (context, index) => const Divider(height: 1),
    //   itemBuilder: (context, index) {
    //     if (index == incomes.length) {
    //       final monthTotal = _monthTotalCents;
    //       final recurring = _recurringTotalCents;

    //       return Column(
    //         children: [
    //           ListTile(
    //             title: Text(
    //               'Entra em ${MonthUtils.label(month)}',
    //               style: theme.textTheme.titleSmall,
    //             ),
    //             trailing: Text(
    //               MoneyUtils.format(monthTotal),
    //               style: theme.textTheme.titleMedium?.copyWith(
    //                 color: theme.colorScheme.primary,
    //               ),
    //             ),
    //           ),

    //           // if (recurring != monthTotal)
    //           //   ListTile(
    //           //     dense: true,
    //           //     title: Text(
    //           //       'Recorrente por mês',
    //           //       style: theme.textTheme.bodySmall?.copyWith(
    //           //         color: theme.colorScheme.onSurfaceVariant,
    //           //       ),
    //           //     ),
    //           //     trailing: Text(
    //           //       MoneyUtils.format(recurring),
    //           //       style: theme.textTheme.bodySmall?.copyWith(
    //           //         color: theme.colorScheme.onSurfaceVariant,
    //           //       ),
    //           //     ),
    //           //   ),
    //         ],
    //       );
    //     }
    //     // return null;

    //     // final income = incomes[index];
    //     // return IncomeTile(
    //     //   income: income,
    //     //   month: month,
    //     //   onTap: () => onOpen(income),
    //     // );
    //   },
    // );
  }
}
