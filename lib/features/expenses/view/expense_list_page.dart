import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:signals/signals_flutter.dart';

import '../../../core/di/injector.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/shared/view_state.dart';
import '../../../core/shared/widgets/empty_state_widget.dart';
import '../../../core/shared/widgets/failure_card_widget.dart';
import '../../../core/shared/widgets/state_transition.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/month.dart';
import '../../../data/models/expense_model.dart';
import '../controller/expense_list_controller.dart';
import '../widgets/expense_tile.dart';

/// Lista de gastos — a porta de entrada do CRUD.
class ExpenseListPage extends StatefulWidget {
  const ExpenseListPage({super.key});

  @override
  State<ExpenseListPage> createState() => _ExpenseListPageState();
}

class _ExpenseListPageState extends State<ExpenseListPage> {
  final _controller = getIt<ExpenseListController>();

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
      appBar: AppBar(title: const Text('Gastos'), centerTitle: true),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            _openAndReload(context.pushNamed(AppRoutes.expenseForm)),
        icon: const Icon(Icons.add),
        label: const Text('Novo gasto'),
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
                    onRetry: _controller.load,
                  ),
                ),
              ),
              Loaded(data: final expenses) => _ExpenseList(
                expenses: expenses,
                onRefresh: _controller.refresh,
                onOpen: (expense) => _openAndReload(
                  context.pushNamed(
                    AppRoutes.expenseDetail,
                    pathParameters: {RouteParams.id: expense.id},
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

class _ExpenseList extends StatelessWidget {
  const _ExpenseList({
    required this.expenses,
    required this.onRefresh,
    required this.onOpen,
  });

  final List<ExpenseModel> expenses;
  final Future<void> Function() onRefresh;
  final void Function(ExpenseModel expense) onOpen;

  String get _month => Month.current();

  /// Quanto sai na competência corrente — o mesmo número que a home mostra
  /// para este mês.
  ///
  /// Sai do `amountCentsIn` e não do `amountCents` porque este último vem nulo
  /// na listagem sem `?month`. Somar o campo direto daria zero.
  int get _monthTotalCents => expenses.fold(
    0,
    (total, expense) => total + (expense.amountCentsIn(_month) ?? 0),
  );

  /// A parte que se repete: só os gastos sem fim marcado. A diferença para o
  /// total do mês é o que sai uma vez só — o presente, a consulta avulsa.
  int get _recurringTotalCents => expenses
      .where((expense) => expense.endMonth == null)
      .fold(
        0,
        (total, expense) => total + (expense.amountCentsIn(_month) ?? 0),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (expenses.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.payments_outlined,
        title: 'Nenhum gasto cadastrado',
        message:
            'Comece pelo que se repete todo mês — aluguel, streaming, escola.',
        onRefresh: onRefresh,
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        // Espaço no fim para o FAB não cobrir o último item.
        padding: const EdgeInsets.only(bottom: 88),
        itemCount: expenses.length + 1,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index == expenses.length) {
            final monthTotal = _monthTotalCents;
            final recurring = _recurringTotalCents;

            return Column(
              children: [
                ListTile(
                  title: Text(
                    'Sai em ${Month.label(_month)}',
                    style: theme.textTheme.titleSmall,
                  ),
                  trailing: Text(
                    Money.format(monthTotal),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.error,
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
                      Money.format(recurring),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            );
          }

          final expense = expenses[index];
          return ExpenseTile(expense: expense, onTap: () => onOpen(expense));
        },
      ),
    );
  }
}
