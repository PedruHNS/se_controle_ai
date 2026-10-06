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
import '../../../data/models/expense_model.dart';
import '../controller/expense_list_controller.dart';
import '../widgets/expense_tile.dart';
import 'package:se_controle_ai/data/enums/payment_method.dart';

/// Lista de gastos — a porta de entrada do CRUD.
///
/// A mesma tela serve a lista inteira e o recorte por forma de pagamento: quem
/// vem da seção "Dinheiro e crédito" da home chega sem filtro, quem vem da
/// seção "Dinheiro" chega com `DEBIT`. O filtro é lido da rota pelo router e
/// entregue aqui — o controller não conhece `GoRouterState`.
class ExpenseListPage extends StatefulWidget {
  const ExpenseListPage({this.paymentMethod, super.key});

  /// Nulo = tudo que sai no mês, débito e cartão.
  final PaymentMethod? paymentMethod;

  @override
  State<ExpenseListPage> createState() => _ExpenseListPageState();
}

class _ExpenseListPageState extends State<ExpenseListPage> {
  final _controller = getIt<ExpenseListController>();

  /// O mês que a home selecionou. Manda em tudo nesta tela: no valor de cada
  /// linha, no total do rodapé e — desde o `?activeFrom` (GFX-11) — em quem
  /// aparece, já que o que acabou antes dele não é mais assunto aqui. Quem
  /// refaz a busca na troca de mês é o controller, com um `effect`.
  final _selectedMonth = getIt<SelectedMonthService>();

  /// O controller é singleton e sobrevive à saída da tela, então o filtro tem
  /// de ser reafirmado a cada montagem — senão voltar da seção "Dinheiro" para
  /// a lista completa mostraria o recorte anterior. `applyFilter` só rebusca
  /// quando o filtro muda de fato.
  @override
  void initState() {
    super.initState();
    _controller.applyFilter(widget.paymentMethod);
  }

  /// Recarrega ao voltar do formulário ou do detalhe: as duas telas podem ter
  /// criado, reajustado ou apagado, e a lista não fica sabendo sozinha.
  Future<void> _openAndReload(Future<Object?> navigation) async {
    await navigation;
    if (!mounted) return;
    await _controller.refresh();
  }

  /// O título diz qual recorte está na tela: sem ele, a lista filtrada é
  /// indistinguível da completa que faltou carregar.
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
        onPressed: () =>
            _openAndReload(context.pushNamed(AppRoutes.expenseForm)),
        icon: const Icon(Icons.add),
        label: const Text('Novo gasto'),
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
              Loaded(data: final expenses) => _ExpenseList(
                expenses: expenses,
                month: month,
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
    required this.month,
    required this.onRefresh,
    required this.onOpen,
  });

  final List<ExpenseModel> expenses;

  /// A competência selecionada na home.
  final String month;

  final Future<void> Function() onRefresh;
  final void Function(ExpenseModel expense) onOpen;

  /// Quanto sai na competência exibida — o mesmo número que a home mostra
  /// para este mês.
  ///
  /// Sai do `amountCentsIn` e não do `amountCents` porque este último vem nulo
  /// na listagem sem `?month`. Somar o campo direto daria zero.
  int get _monthTotalCents => expenses.fold(
    0,
    (total, expense) => total + (expense.amountCentsIn(month) ?? 0),
  );

  /// A parte que se repete: só os gastos sem fim marcado. A diferença para o
  /// total do mês é o que sai uma vez só — o presente, a consulta avulsa.
  int get _recurringTotalCents => expenses
      .where((expense) => expense.endMonth == null)
      .fold(0, (total, expense) => total + (expense.amountCentsIn(month) ?? 0));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (expenses.isEmpty) {
      // "neste mês" e não "cadastrado": com o `?activeFrom`, a lista vazia pode
      // ser tanto quem nunca cadastrou nada quanto quem só tem gasto que já
      // acabou. Prometer "nenhum gasto cadastrado" para o segundo seria mentira.
      return EmptyStateWidget(
        icon: Icons.payments_outlined,
        title: 'Nenhum gasto em ${MonthUtils.label(month)}',
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
                    'Sai em ${MonthUtils.label(month)}',
                    style: theme.textTheme.titleSmall,
                  ),
                  trailing: Text(
                    MoneyUtils.format(monthTotal),
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
                      MoneyUtils.format(recurring),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            );
          }

          final expense = expenses[index];
          return ExpenseTile(
            expense: expense,
            monthSelected: month,
            onTap: () => onOpen(expense),
          );
        },
      ),
    );
  }
}
