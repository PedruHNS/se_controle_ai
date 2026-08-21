import 'package:flutter/material.dart';

/// "Não há nada aqui ainda", com o gesto de recarregar preservado.
///
/// O widget inclui o `RefreshIndicator` e o scroll em vez de só o miolo, e não
/// é detalhe: a lista vazia é justamente onde o pull-to-refresh some sem
/// querer, porque sem conteúdo não há o que rolar. É o `AlwaysScrollableScroll
/// Physics` que mantém o gesto vivo, e deixá-lo a cargo de quem chama é
/// convidar a esquecer — foi o que aconteceu na projeção, que ficou sem.
///
/// A frase de [message] é o que separa isto de uma tela morta: ela diz o
/// próximo passo ("comece pelo salário"), não repete o título em outras
/// palavras.
class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({
    required this.icon,
    required this.title,
    required this.message,
    this.onRefresh,
    super.key,
  });

  final IconData icon;
  final String title;

  /// O próximo passo, não um sinônimo do título.
  final String message;

  /// Quando nulo, não há gesto de recarregar — é o caso de tela que não busca
  /// nada, como a projeção sem meses a projetar.
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final content = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        // Um quarto da altura em vez de centralizar: centralizado de verdade,
        // o texto fica atrás do teclado em tela pequena e o gesto de puxar
        // começa longe demais do topo.
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.25),
        Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );

    final refresh = onRefresh;
    if (refresh == null) return content;

    return RefreshIndicator(onRefresh: refresh, child: content);
  }
}
