import 'package:flutter/material.dart';

import '../../../core/utils/money.dart';
import '../../../data/models/monthly_summary_model.dart';

/// O cabeçalho do mês: saldo em destaque, ganho e gasto ao lado, e quanto do
/// ganho já está comprometido.
class BalanceCard extends StatelessWidget {
  const BalanceCard({required this.summary, super.key});

  final MonthlySummaryModel summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final negative = summary.isNegative;

    // Vermelho só quando falta dinheiro. Usar a cor de erro para saldo positivo
    // treinaria o olho a ignorar o vermelho justamente quando ele importa.
    final balanceColor = negative
        ? theme.colorScheme.error
        : theme.colorScheme.primary;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              negative ? 'Faltam' : 'Sobram',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              Money.format(summary.balanceCents),
              style: theme.textTheme.displaySmall?.copyWith(
                color: balanceColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                // "Entra"/"Sai" e não "Ganhos"/"Gastos": as seções abaixo já se
                // chamam assim, e repetir a mesma palavra em dois níveis da tela
                // faz o olho procurar diferença onde não há.
                Expanded(
                  child: _Figure(
                    label: 'Entra',
                    value: summary.incomeCents,
                    icon: Icons.arrow_downward,
                    color: theme.colorScheme.primary,
                  ),
                ),
                Expanded(
                  child: _Figure(
                    label: 'Sai',
                    value: summary.expenseCents,
                    icon: Icons.arrow_upward,
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ),
            if (summary.committedPercent != null) ...[
              const SizedBox(height: 20),
              _CommittedBar(percent: summary.committedPercent!),
            ],
          ],
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          Money.format(value),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _CommittedBar extends StatelessWidget {
  const _CommittedBar({required this.percent});

  /// Vem do backend em 0–100, e pode passar de 100 quando o gasto supera o ganho.
  final double percent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overCommitted = percent > 100;

    final color = switch (percent) {
      > 100 => theme.colorScheme.error,
      > 80 => Colors.orange,
      _ => theme.colorScheme.primary,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Comprometido',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              '${percent.toStringAsFixed(1)}%',
              style: theme.textTheme.labelLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            // A barra satura em 100%: passar disso encheria a barra e ainda
            // pediria um valor > 1, que o widget não aceita. O número ao lado já
            // mostra o estouro.
            value: (percent / 100).clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        if (overCommitted) ...[
          const SizedBox(height: 6),
          Text(
            'Os gastos passaram do que entra neste mês.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }
}
