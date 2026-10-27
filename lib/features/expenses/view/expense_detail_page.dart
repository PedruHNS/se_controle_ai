import 'package:flutter/material.dart';
import 'package:se_controle_ai/core/shared/widgets/custom_button_default_widget.dart';
import 'package:se_controle_ai/data/services/navigation_service.dart';
import 'package:signals/signals_flutter.dart';

import '../../../core/di/injector.dart';
import '../../../core/router/app_routes.dart';
import '../../../data/enums/expense_type.dart';
import '../../../data/models/expense_model.dart';
import '../../../data/services/selected_month_service.dart';
import '../../incomes/widgets/action_card_widget.dart';
import '../controller/expense_controller.dart';
import '../widgets/expense_amount_dialog.dart';
import '../widgets/expense_closure_dialog.dart';
import '../widgets/expense_detail_card_widget.dart';
import '../widgets/expense_reschedule_dialog.dart';
import '../widgets/expense_settlement_dialog.dart';
import '../widgets/installments_card.dart';

class ExpenseDetailPage extends StatefulWidget {
  final ExpenseModel expense;
  const ExpenseDetailPage({required this.expense, super.key});

  @override
  State<ExpenseDetailPage> createState() => _ExpenseDetailPageState();
}

class _ExpenseDetailPageState extends State<ExpenseDetailPage> {
  final _controller = getIt<ExpenseController>();
  final _nav = getIt<NavigationService>();

  final _selectedMonth = getIt<SelectedMonthService>();

  @override
  void initState() {
    super.initState();
    _controller.loadCardLabel(widget.expense.creditCardId);
  }

  void _confirmDelete(ExpenseModel expense) {
    showDialog<void>(
      context: context,
      builder: (context) => SignalBuilder(
        builder: (context) {
          final deleting = _controller.saving.value;
          return PopScope(
            canPop: false,
            child: AlertDialog(
              title: const Text('Excluir gasto'),
              content: Text(
                'Apaga "${expense.description}" e todo o histórico, como se '
                'nunca tivesse existido. Para registrar que você parou de '
                'pagar, use Encerrar.',
              ),
              actions: [
                TextButton(
                  onPressed: deleting
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                CustomButtonDefaultWidget(
                  isLoading: deleting,
                  onPressed: () async => await _controller.delete(expense.id),
                  title: 'Excluir',
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gasto'), centerTitle: true),
      body: SignalBuilder(
        builder: (context) {
          final expense = widget.expense;
          final working = _controller.saving.value;
          final installment = expense.type == ExpenseType.installment;
          final openFixed =
              expense.type == ExpenseType.fixed && expense.endMonth == null;

          return ListView(
            padding: const .symmetric(horizontal: 12, vertical: 24),
            children: [
              ExpenseDetailCardWidget(
                expense: expense,
                month: _selectedMonth.month.value,
                cardLabel: _controller.cardLabel.value,
              ),
              Padding(
                padding: const .symmetric(vertical: 8),
                child: Column(
                  spacing: 8,
                  children: [
                    ActionCardWidget(
                      icon: Icons.tune,
                      title: 'Editar dados',
                      subtitle:
                          'Descrição, categoria, observação e forma de '
                          'pagamento. Vale para todos os meses.',
                      onTap: working
                          ? null
                          : () => _nav.pushNamed(
                              AppRoutes.expenseEdit,
                              extra: expense,
                            ),
                    ),
                    Visibility(
                      visible: installment,
                      child: Column(
                        spacing: 8,
                        children: [
                          ActionCardWidget(
                            icon: Icons.call_split,
                            title: 'Reparcelar',
                            subtitle:
                                'Mudou o total ou o número de vezes. As '
                                'parcelas já cobradas ficam como estão.',
                            onTap: working
                                ? null
                                : () => showExpenseRescheduleDialog(
                                    context,
                                    controller: _controller,
                                    expense: expense,
                                  ),
                          ),
                          ActionCardWidget(
                            icon: Icons.done_all,
                            title: 'Quitar',
                            subtitle:
                                'Paguei o resto adiantado. As parcelas de um '
                                'mês em diante somem.',
                            onTap: working
                                ? null
                                : () => showExpenseSettlementDialog(
                                    context,
                                    controller: _controller,
                                    expense: expense,
                                  ),
                          ),
                        ],
                      ),
                    ),
                    Visibility(
                      visible: openFixed,
                      child: Column(
                        spacing: 8,
                        children: [
                          ActionCardWidget(
                            icon: Icons.trending_up,
                            title: 'Reajustar',
                            subtitle:
                                'O valor subiu a partir de um mês. O passado '
                                'fica como está.',
                            onTap: working
                                ? null
                                : () => showExpenseAmountDialog(
                                    context,
                                    controller: _controller,
                                    expense: expense,
                                    mode: ExpenseAmountMode.adjust,
                                  ),
                          ),
                          ActionCardWidget(
                            icon: Icons.edit_outlined,
                            title: 'Corrigir valor',
                            subtitle:
                                'O valor estava errado. Vale também para os '
                                'meses que já passaram.',
                            onTap: working
                                ? null
                                : () => showExpenseAmountDialog(
                                    context,
                                    controller: _controller,
                                    expense: expense,
                                    mode: ExpenseAmountMode.correct,
                                  ),
                          ),
                          ActionCardWidget(
                            icon: Icons.event_busy_outlined,
                            title: 'Encerrar',
                            subtitle: 'Parei de pagar. O histórico continua.',
                            onTap: working
                                ? null
                                : () => showExpenseClosureDialog(
                                    context,
                                    controller: _controller,
                                    expense: expense,
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              ActionCardWidget(
                icon: Icons.delete_outline,
                title: 'Excluir',
                subtitle: 'Cadastrei errado. Apaga o gasto e todo o histórico.',
                destructive: true,
                onTap: working ? null : () => _confirmDelete(expense),
              ),
              Visibility(
                visible: expense.installments.isNotEmpty,
                child: Padding(
                  padding: const .only(top: 16),
                  child: InstallmentsCard(
                    installments: expense.installments,
                    currentMonth: _selectedMonth.month.value,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
