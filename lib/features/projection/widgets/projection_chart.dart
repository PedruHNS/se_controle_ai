import 'package:flutter/material.dart';

import '../../../core/utils/money.dart';
import '../../../core/utils/month.dart';
import '../../../data/models/month_projection_model.dart';

/// O saldo acumulado mês a mês, em barras.
///
/// **Desenhado à mão, sem biblioteca de gráfico.** São barras verticais com uma
/// linha de zero — não há eixo com escala, legenda nem interação, e uma
/// dependência nova custaria mais do que este `CustomPainter` de sessenta
/// linhas. Se um dia a tela precisar de zoom, tooltip ou várias séries, aí a
/// conta muda.
///
/// A barra é o **acumulado**, e não o saldo do mês: a pergunta da tela é
/// "quanto vou ter juntado", e um mês negativo no meio de uma sequência boa não
/// é o que assusta — o acumulado cruzar o zero é.
class ProjectionChart extends StatelessWidget {
  const ProjectionChart({required this.projection, super.key});

  final List<MonthProjectionModel> projection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 160,
          child: CustomPaint(
            painter: _ProjectionPainter(
              projection: projection,
              positive: theme.colorScheme.primary,
              negative: theme.colorScheme.error,
              baseline: theme.colorScheme.outlineVariant,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              Month.shortLabel(projection.first.month),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              Money.formatCompact(projection.last.cumulativeBalanceCents),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              Month.shortLabel(projection.last.month),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ProjectionPainter extends CustomPainter {
  _ProjectionPainter({
    required this.projection,
    required this.positive,
    required this.negative,
    required this.baseline,
  });

  final List<MonthProjectionModel> projection;
  final Color positive;
  final Color negative;
  final Color baseline;

  @override
  void paint(Canvas canvas, Size size) {
    if (projection.isEmpty) return;

    final values = projection
        .map((month) => month.cumulativeBalanceCents)
        .toList(growable: false);

    // A escala inclui o zero sempre: sem isso, uma sequência toda positiva
    // desenharia a menor barra colada no chão e daria a impressão de saldo
    // zerado num mês em que sobra dinheiro.
    final maxValue = [0, ...values].reduce((a, b) => a > b ? a : b);
    final minValue = [0, ...values].reduce((a, b) => a < b ? a : b);
    final span = (maxValue - minValue).abs();
    if (span == 0) return;

    final zeroY = size.height * (maxValue / span);
    final slot = size.width / values.length;
    final barWidth = (slot * 0.6).clamp(2.0, 24.0);

    canvas.drawLine(
      Offset(0, zeroY),
      Offset(size.width, zeroY),
      Paint()
        ..color = baseline
        ..strokeWidth = 1,
    );

    for (var i = 0; i < values.length; i++) {
      final value = values[i];
      final height = size.height * (value.abs() / span);
      final left = slot * i + (slot - barWidth) / 2;

      final rect = value >= 0
          ? Rect.fromLTWH(left, zeroY - height, barWidth, height)
          : Rect.fromLTWH(left, zeroY, barWidth, height);

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        Paint()..color = value >= 0 ? positive : negative,
      );
    }
  }

  @override
  bool shouldRepaint(_ProjectionPainter oldDelegate) =>
      oldDelegate.projection != projection ||
      oldDelegate.positive != positive ||
      oldDelegate.negative != negative;
}
