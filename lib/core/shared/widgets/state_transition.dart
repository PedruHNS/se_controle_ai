import 'package:flutter/material.dart';

/// Suaviza a troca entre carregando, erro e conteúdo.
///
/// Sem isto o `switch (ViewState)` troca de widget no mesmo frame: o spinner
/// some e a lista aparece de uma vez, o que lê como piscada — principalmente
/// quando a resposta é rápida e o spinner mal apareceu.
///
/// **Não anima recarga silenciosa**, e isso é de propósito. O `AnimatedSwitcher`
/// compara por tipo e chave, então uma lista que volta com dados novos continua
/// sendo a mesma lista e não pisca. Só a mudança de *estado* — spinner para
/// lista, lista para erro — atravessa a animação. Se animasse toda atualização,
/// o pull-to-refresh ficaria com um flash a cada puxada.
///
/// A saída é `FadeTransition` puro, sem deslizamento: o conteúdo troca no
/// lugar, e movimento aqui sugeriria navegação, que não houve.
class StateTransition extends StatelessWidget {
  const StateTransition({
    required this.stateKey,
    required this.child,
    super.key,
  });

  /// O que identifica o estado — na prática, `state.runtimeType`.
  ///
  /// **Sem isto o widget não faz nada.** O `AnimatedSwitcher` decide se anima
  /// comparando chave e tipo do filho, e filho sem chave é tratado como o
  /// mesmo de antes, mesmo trocando de tipo: a transição some sem erro nenhum,
  /// e fica um widget decorativo no meio do caminho.
  ///
  /// Chavear pelo tipo do **widget** também não serve: `Loading` e `Failed`
  /// renderizam os dois um `Center`, e a troca entre eles não animaria. Quem
  /// sabe que o estado mudou é o `ViewState`, não a árvore.
  final Object stateKey;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: KeyedSubtree(key: ValueKey(stateKey), child: child),
    );
  }
}
