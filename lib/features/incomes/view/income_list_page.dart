import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:signals/signals_flutter.dart';

import '../../../core/di/injector.dart';
import '../../../data/services/selected_month_service.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/shared/view_state.dart';
import '../../../core/shared/widgets/empty_state_widget.dart';
import '../../../core/shared/widgets/failure_card_widget.dart';
import '../../../core/shared/widgets/state_transition.dart';
import '../../../core/utils/money_utils.dart';
import '../../../core/utils/month_utils.dart';
import '../../../data/models/income_model.dart';
import '../controller/income_list_controller.dart';
import '../widgets/income_tile.dart';

/// Lista de ganhos — a porta de entrada do CRUD.
class IncomeListPage extends StatefulWidget {
  const IncomeListPage({super.key});

  @override
  State<IncomeListPage> createState() => _IncomeListPageState();
}

class _IncomeListPageState extends State<IncomeListPage> {
  final _controller = getIt<IncomeListController>();

  /// O mês que a home selecionou. A lista em si não depende dele — a busca é
  /// sem `?month`, de propósito —, mas o valor de cada linha e o total do rodapé
  /// dependem: é o mês que responde "quanto disto entra".
  final _selectedMonth = getIt<SelectedMonthService>();

  /// Recarrega ao voltar do formulário ou do detalhe: as duas telas podem ter
  /// criado, reajustado ou apagado, e a lista não fica sabendo sozinha.
  Future<void> _openAndReload(Future<Object?> navigation) async {
    await navigation;
    if (!mounted) return;
    await _controller.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ganhos'), centerTitle: true),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            _openAndReload(context.pushNamed(AppRoutes.incomeForm)),
        icon: const Icon(Icons.add),
        label: const Text('Novo ganho'),
      ),
      body: SignalBuilder(
        builder: (context) {
          final state = _controller.state.value;
          // Lido aqui dentro, e não no `build`, para o total se refazer sozinho
          // se o mês trocar com esta tela montada.
          final month = _selectedMonth.month.value;

          return StateTransition(
            stateKey: state.runtimeType,
            child: switch (state) {
              Loading() => const Center(child: CircularProgressIndicator()),
              Failed(failure: final failure) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: FailureCardWidget(
                    failure: failure,
                    onRetry: _controller.load,
                  ),
                ),
              ),
              Loaded(data: final incomes) => _IncomeList(
                incomes: incomes,
                month: month,
                onRefresh: _controller.refresh,
                onOpen: (income) => _openAndReload(
                  context.pushNamed(
                    AppRoutes.incomeDetail,
                    pathParameters: {RouteParams.id: income.id},
                  ),
                ),
              ),
            },
          );
        },
      ),
    );
  }
}

class _IncomeList extends StatelessWidget {
  const _IncomeList({
    required this.incomes,
    required this.month,
    required this.onRefresh,
    required this.onOpen,
  });

  final List<IncomeModel> incomes;

  /// A competência selecionada na home.
  final String month;

  final Future<void> Function() onRefresh;
  final void Function(IncomeModel income) onOpen;

  /// Quanto entra na competência exibida — o mesmo número que a home mostra
  /// para este mês.
  ///
  /// Sai do `amountCentsIn` e não do `amountCents` porque este último é o valor
  /// da vigência mais recente, que pode ser uma que só começa no mês que vem
  /// (reajuste agendado). Somar o campo direto daria dois totais diferentes
  /// para o mesmo mês em duas telas do mesmo app.
  int get _monthTotalCents => incomes.fold(
    0,
    (total, income) => total + (income.amountCentsIn(month) ?? 0),
  );

  /// A parte que se repete: só os ganhos sem fim marcado. A diferença para o
  /// total do mês é o que entrou uma vez só — venda, presente, 13º.
  int get _recurringTotalCents => incomes
      .where((income) => income.endMonth == null)
      .fold(0, (total, income) => total + (income.amountCentsIn(month) ?? 0));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (incomes.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.trending_up,
        title: 'Nenhum ganho cadastrado',
        message: 'Comece pelo salário — o resumo do mês depende dele.',
        onRefresh: onRefresh,
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        // Espaço no fim para o FAB não cobrir o último item.
        padding: const EdgeInsets.only(bottom: 88),
        itemCount: incomes.length + 1,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index == incomes.length) {
            final monthTotal = _monthTotalCents;
            final recurring = _recurringTotalCents;

            return Column(
              children: [
                ListTile(
                  title: Text(
                    'Entra em ${MonthUtils.label(month)}',
                    style: theme.textTheme.titleSmall,
                  ),
                  trailing: Text(
                    MoneyUtils.format(monthTotal),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                // A segunda linha só aparece quando há avulso no mês — sem
                // diferença entre os dois números, ela seria repetição.
                if (recurring != monthTotal)
                  ListTile(
                    dense: true,
                    title: Text(
                      'Recorrente por mês',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    trailing: Text(
                      MoneyUtils.format(recurring),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            );
          }

          final income = incomes[index];
          return IncomeTile(
            income: income,
            month: month,
            onTap: () => onOpen(income),
          );
        },
      ),
    );
  }
}
