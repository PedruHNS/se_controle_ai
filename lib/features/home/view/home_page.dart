import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:signals/signals_flutter.dart';

import '../../../core/di/injector.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/shared/view_state.dart';
import '../../../core/shared/widgets/failure_card_widget.dart';
import '../../../data/models/monthly_summary_model.dart';
import '../controller/home_controller.dart';
import '../widgets/balance_card.dart';
import '../widgets/credit_card_invoice_card.dart';
import '../widgets/summary_section.dart';

/// Resumo do mês — tela inicial.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // O controller é um lazySingleton do get_it, e é o get_it que o libera pelo
  // `dispose:` do registro — por isso não há `dispose` aqui. Consequência
  // desejada: o mês selecionado continua o mesmo ao sair da home e voltar.
  final _controller = getIt<HomeController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: SignalBuilder(
          builder: (context) => Text(_controller.monthLabel.value),
        ),
        centerTitle: true,
        leading: SignalBuilder(
          builder: (context) => IconButton(
            tooltip: 'Mês anterior',
            icon: const Icon(Icons.chevron_left),
            onPressed: _controller.canGoPrevious.value
                ? _controller.goToPreviousMonth
                : null,
          ),
        ),
        actions: [
          SignalBuilder(
            builder: (context) => IconButton(
              tooltip: 'Próximo mês',
              icon: const Icon(Icons.chevron_right),
              onPressed: _controller.canGoNext.value
                  ? _controller.goToNextMonth
                  : null,
            ),
          ),
        ],
      ),
      // O atalho fica **no corpo**, não no `bottom` do AppBar. No AppBar ele
      // disputava altura com o título: o `bottom` reservava zero, o botão ocupava
      // seu espaço mesmo assim e empurrava o rótulo do mês para fora da barra —
      // dava a impressão de que a navegação tinha trocado o mês por um botão.
      //
      // Aqui também fica visível nos três estados: navegar para um mês que falha
      // ao carregar não pode tirar o caminho de volta.
      body: Column(
        children: [
          SignalBuilder(
            builder: (context) => _controller.isCurrentMonth.value
                ? const SizedBox.shrink()
                : _BackToCurrentMonth(onPressed: _controller.goToCurrentMonth),
          ),
          Expanded(
            child: SignalBuilder(
              builder: (context) => switch (_controller.state.value) {
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
                Loaded(data: final summary) => _SummaryContent(
                  summary: summary,
                  onRefresh: _controller.refresh,
                ),
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Faixa de volta ao mês corrente, visível só fora dele.
///
/// Cor de destaque em vez de botão solto: a faixa também serve de aviso de que o
/// que está na tela não é o mês de hoje.
class _BackToCurrentMonth extends StatelessWidget {
  const _BackToCurrentMonth({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.secondaryContainer,
      child: SizedBox(
        width: double.infinity,
        child: TextButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.today, size: 16),
          label: const Text('Voltar para o mês atual'),
          style: TextButton.styleFrom(
            foregroundColor: theme.colorScheme.onSecondaryContainer,
            shape: const RoundedRectangleBorder(),
          ),
        ),
      ),
    );
  }
}

class _SummaryContent extends StatelessWidget {
  const _SummaryContent({required this.summary, required this.onRefresh});

  final MonthlySummaryModel summary;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        // AlwaysScrollable para o pull-to-refresh funcionar mesmo quando o
        // conteúdo é curto e não haveria rolagem.
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          BalanceCard(summary: summary),
          const SizedBox(height: 16),
          SummarySection(
            title: 'Ganhos',
            icon: Icons.trending_up,
            items: summary.incomes,
            totalCents: summary.incomeCents,
            emptyMessage: 'Nenhum ganho cadastrado. Toque para adicionar um.',
            onTap: () => context.pushNamed(AppRoutes.incomes),
          ),
          if (summary.debit.items.isNotEmpty) ...[
            const SizedBox(height: 16),
            SummarySection(
              title: 'Débito e dinheiro',
              icon: Icons.payments_outlined,
              items: summary.debit.items,
              totalCents: summary.debit.totalCents,
            ),
          ],
          for (final invoice in summary.creditCards) ...[
            const SizedBox(height: 16),
            CreditCardInvoiceCard(invoice: invoice),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
