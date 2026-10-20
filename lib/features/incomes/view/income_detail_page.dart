import 'package:flutter/material.dart';
import 'package:se_controle_ai/features/incomes/widgets/action_card_widget.dart';
import 'package:signals/signals_flutter.dart';

import '../../../core/di/injector.dart';
import '../../../data/models/income_model.dart';
import '../controller/income_controller.dart';
import '../widgets/income_amount_dialog.dart';
import '../widgets/income_closure_dialog.dart';
import '../widgets/income_detail_card_widget.dart';

/// Um ganho: valor vigente, histórico e as quatro operações.
class IncomeDetailPage extends StatefulWidget {
  final IncomeModel income;
  const IncomeDetailPage({required this.income, super.key});

  @override
  State<IncomeDetailPage> createState() => _IncomeDetailPageState();
}

class _IncomeDetailPageState extends State<IncomeDetailPage> {
  // O da lista: quem o libera é ela, ao sair.
  final _controller = getIt<IncomeController>();

  Future<void> _confirmDelete(IncomeModel income) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir ganho'),
        content: Text(
          'Apaga "${income.description}" e todo o histórico, como se nunca '
          'tivesse existido. Para registrar que você parou de receber, use '
          'Encerrar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _controller.delete(income.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ganho'), centerTitle: true),
      // O ganho é o que veio da lista: a tela não busca nem muda nada nele, e
      // quem mostra o resultado de uma operação é a lista, ao voltar.
      body: SignalBuilder(
        builder: (context) {
          final income = widget.income;
          final working = _controller.saving.value;

          return ListView(
            padding: .symmetric(horizontal: 12, vertical: 24),
            children: [
              IncomeDetailCardWidget(income: income),

              Padding(
                padding: const .symmetric(vertical: 8),
                child: Visibility(
                  visible: income.endMonth == null,
                  child: Column(
                    spacing: 8,
                    children: [
                      ActionCardWidget(
                        icon: Icons.trending_up,
                        title: 'Reajustar',
                        subtitle:
                            'Recebi um aumento a partir de um mês. O passado '
                            'fica como está.',
                        onTap: working
                            ? null
                            : () => showIncomeAmountDialog(
                                context,
                                controller: _controller,
                                income: income,
                                mode: IncomeAmountMode.adjust,
                              ),
                      ),
                      ActionCardWidget(
                        icon: Icons.edit_outlined,
                        title: 'Corrigir valor',
                        subtitle:
                            'O valor estava errado. Vale também para os meses '
                            'que já passaram.',
                        onTap: working
                            ? null
                            : () => showIncomeAmountDialog(
                                context,
                                controller: _controller,
                                income: income,
                                mode: IncomeAmountMode.correct,
                              ),
                      ),
                      ActionCardWidget(
                        icon: Icons.event_busy_outlined,
                        title: 'Encerrar',
                        subtitle: 'Parei de receber. O histórico continua.',
                        onTap: working
                            ? null
                            : () => showIncomeClosureDialog(
                                context,
                                controller: _controller,
                                income: income,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              ActionCardWidget(
                icon: Icons.delete_outline,
                title: 'Excluir',
                subtitle: 'Cadastrei errado. Apaga o ganho e todo o histórico.',
                destructive: true,
                onTap: working ? null : () => _confirmDelete(income),
              ),
            ],
          );
        },
      ),
    );
  }
}
