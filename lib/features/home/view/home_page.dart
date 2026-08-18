import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';

import '../../../core/di/injector.dart';
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
  // StatefulWidget e não um controller global: é o que dá um ponto de dispose
  // para os signals. O registro no get_it é factory, então cada página tem a
  // própria instância.
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0),
          child: SignalBuilder(
            // Só aparece quando saiu do mês corrente — atalho para voltar sem
            // precisar de N toques na seta.
            builder: (context) => _controller.isCurrentMonth.value
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextButton.icon(
                      onPressed: _controller.goToCurrentMonth,
                      icon: const Icon(Icons.today, size: 16),
                      label: const Text('Voltar para o mês atual'),
                    ),
                  ),
          ),
        ),
      ),
      body: SignalBuilder(
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
    );
  }
}

class _SummaryContent extends StatelessWidget {
  const _SummaryContent({required this.summary, required this.onRefresh});

  final MonthlySummaryModel summary;
  final Future<void> Function() onRefresh;

  bool get _isEmpty =>
      summary.incomes.isEmpty &&
      summary.debit.isEmpty &&
      summary.creditCards.isEmpty;

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
          if (_isEmpty)
            const _EmptyMonth()
          else ...[
            const SizedBox(height: 16),
            SummarySection(
              title: 'Ganhos',
              icon: Icons.trending_up,
              items: summary.incomes,
              totalCents: summary.incomeCents,
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
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _EmptyMonth extends StatelessWidget {
  const _EmptyMonth();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 48,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text('Nada lançado neste mês', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Cadastre um ganho ou um gasto para ver o resumo.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
