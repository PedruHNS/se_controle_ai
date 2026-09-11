import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// A moldura dos cards do dashboard: título, um respiro e o conteúdo.
///
/// Existe para os sete cards terem a mesma caixa — mesma cor, mesmo raio, mesma
/// sombra dos tiles de lista do app. O que muda entre eles é só o desenho de
/// dentro.
class DashboardCardWidget extends StatelessWidget {
  const DashboardCardWidget({
    required this.title,
    required this.child,
    this.footnote,
    super.key,
  });

  final String title;
  final Widget child;

  /// A linha pequena do rodapé, quando o card precisa explicar o que o desenho
  /// não diz — a linha de base do ritmo, por exemplo.
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final footnote = this.footnote;

    return Container(
      padding: .all(16),
      decoration: BoxDecoration(
        color: theme.appColors.card,
        borderRadius: .circular(10),
        boxShadow: [
          BoxShadow(
            color: theme.appColors.cardShadow,
            blurRadius: 40,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: .start,
        spacing: 12,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          child,
          if (footnote != null)
            Text(
              footnote,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}
