import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';

import '../../../core/di/injector.dart';
import '../../../core/shared/view_state.dart';
import '../../../core/shared/widgets/failure_card_widget.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/month.dart';
import '../../../data/models/month_projection_model.dart';
import '../controller/projection_controller.dart';
import '../widgets/projection_chart.dart';

/// Para onde o saldo caminha, mês a mês, a partir de hoje.
class ProjectionPage extends StatefulWidget {
  const ProjectionPage({super.key});

  @override
  State<ProjectionPage> createState() => _ProjectionPageState();
}

class _ProjectionPageState extends State<ProjectionPage> {
  final _controller = getIt<ProjectionController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Projeção'), centerTitle: true),
      body: Column(
        children: [
          // Fora do corpo rolável: trocar o horizonte é a única ação da tela, e
          // ela não pode sumir quando se rola a lista de meses.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SignalBuilder(
              builder: (context) => SegmentedButton<int>(
                segments: [
                  for (final horizon in ProjectionController.horizons)
                    ButtonSegment(
                      value: horizon,
                      label: Text('$horizon meses'),
                    ),
                ],
                selected: {_controller.months.value},
                onSelectionChanged: (selection) =>
                    _controller.setMonths(selection.first),
              ),
            ),
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
                Loaded(data: final projection) => _Projection(
                  projection: projection,
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

class _Projection extends StatelessWidget {
  const _Projection({required this.projection, required this.onRefresh});

  final List<MonthProjectionModel> projection;
  final Future<void> Function() onRefresh;

  /// O primeiro mês em que o acumulado fica negativo — a única pergunta que
  /// esta tela responde e nenhuma outra responde.
  MonthProjectionModel? get _firstNegative {
    for (final month in projection) {
      if (month.cumulativeBalanceCents < 0) return month;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (projection.isEmpty) {
      return const Center(child: Text('Sem meses para projetar.'));
    }

    final negative = _firstNegative;
    final last = projection.last;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Acumulado até ${Month.label(last.month)}',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    Money.format(last.cumulativeBalanceCents),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: last.cumulativeBalanceCents < 0
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ProjectionChart(projection: projection),
                ],
              ),
            ),
          ),

          // O aviso vem antes da lista: quem abre a projeção e tem um mês no
          // vermelho pela frente precisa ver isso sem rolar.
          if (negative != null) ...[
            const SizedBox(height: 12),
            Card(
              margin: EdgeInsets.zero,
              color: theme.colorScheme.errorContainer,
              child: ListTile(
                leading: Icon(
                  Icons.warning_amber_rounded,
                  color: theme.colorScheme.onErrorContainer,
                ),
                title: Text(
                  'No vermelho em ${Month.label(negative.month)}',
                  style: TextStyle(color: theme.colorScheme.onErrorContainer),
                ),
                subtitle: Text(
                  'O acumulado chega a ${Money.format(negative.cumulativeBalanceCents)} '
                  'se nada mudar até lá.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),
          for (final month in projection) _MonthRow(month: month),

          const SizedBox(height: 16),
          // O acumulado parte de zero, e não do que existe em conta. Sem esta
          // linha, o número grande lá em cima é uma promessa que o app não fez.
          Text(
            'A conta começa do zero: o acumulado soma o que sobra de cada mês, '
            'sem contar o que você já tem guardado.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthRow extends StatelessWidget {
  const _MonthRow({required this.month});

  final MonthProjectionModel month;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final negative = month.cumulativeBalanceCents < 0;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(Month.label(month.month)),
      subtitle: Text(
        'Entra ${Money.formatCompact(month.incomeCents)} · '
        'sai ${Money.formatCompact(month.expenseCents)}',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            Money.format(month.cumulativeBalanceCents),
            style: theme.textTheme.titleSmall?.copyWith(
              color: negative
                  ? theme.colorScheme.error
                  : theme.colorScheme.primary,
            ),
          ),
          // O saldo do mês em segundo plano: é o acumulado que responde a
          // pergunta da tela, mas sem o do mês não dá para saber por que ele
          // subiu ou caiu.
          Text(
            Money.formatSigned(month.balanceCents),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
