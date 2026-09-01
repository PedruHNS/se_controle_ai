import 'package:flutter/material.dart';

/// O lugar de uma seção da home enquanto ela não chegou.
///
/// Existe porque as quatro seções são buscadas em separado: sem reservar
/// altura, cada resposta que entra empurra as de baixo, e a tela pula três
/// vezes antes de assentar. Com o lugar guardado, o conteúdo aparece onde já
/// estava o espaço dele.
class SummarySectionPlaceholder extends StatelessWidget {
  const SummarySectionPlaceholder({required this.height, super.key});

  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: height,
      child: Card(
        margin: EdgeInsets.zero,
        color: theme.colorScheme.surfaceContainerLow,
        child: const Center(
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
    );
  }
}
