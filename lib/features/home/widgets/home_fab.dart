import 'package:flutter/material.dart';

/// Quanto dura abrir e fechar o menu.
///
/// Exportada porque a cortina que escurece o resumo é desenhada pela
/// [HomePage], fora deste widget, e as duas animações precisam terminar juntas
/// — descompassadas, o escuro chega antes das opções.
const fabMenuDuration = Duration(milliseconds: 180);

/// O botão de criar da home, com as duas coisas que se lança num mês: um ganho
/// e um gasto.
///
/// A home não tinha botão de criar — cadastrar exigia abrir o menu, entrar na
/// lista do assunto e só ali achar o `+`. Três toques para o que é a ação mais
/// repetida do app.
///
/// **Estado controlado, e não interno.** Quem guarda o aberto/fechado é a
/// [HomePage], porque abrir também escurece o conteúdo atrás — e a cortina não
/// cabe aqui dentro: este widget vive no espaço do FAB, que o `Scaffold`
/// desenha por cima do corpo e dimensiona pelo tamanho do botão.
class HomeFab extends StatefulWidget {
  const HomeFab({
    required this.expanded,
    required this.onToggle,
    required this.onNewIncome,
    required this.onNewExpense,
    super.key,
  });

  final bool expanded;

  /// Toque no botão principal. Abre ou fecha, conforme [expanded].
  final VoidCallback onToggle;
  final VoidCallback onNewIncome;
  final VoidCallback onNewExpense;

  @override
  State<HomeFab> createState() => _HomeFabState();
}

class _HomeFabState extends State<HomeFab> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: fabMenuDuration,
    // Já nasce no estado certo: montar com o menu aberto (uma reconstrução da
    // tela com o menu em pé) não pode fazer as ações entrarem animando.
    value: widget.expanded ? 1 : 0,
  );

  late final CurvedAnimation _animation = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  @override
  void didUpdateWidget(HomeFab oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.expanded != oldWidget.expanded) {
      widget.expanded ? _controller.forward() : _controller.reverse();
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Gasto fica **embaixo**, colado no botão principal: é o lançamento do
        // dia a dia, e o de baixo é o mais perto do polegar.
        _FabAction(
          animation: _animation,
          icon: Icons.trending_up,
          onPressed: widget.onNewIncome,
        ),
        _FabAction(
          animation: _animation,
          icon: Icons.payments_outlined,
          onPressed: widget.onNewExpense,
        ),
        FloatingActionButton(
          onPressed: widget.onToggle,
          tooltip: widget.expanded ? 'Fechar' : 'Adicionar',

          child: RotationTransition(
            turns: Tween(begin: 0.0, end: 0.125).animate(_animation),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}

/// Uma das opções do menu, que cresce de baixo para cima ao abrir.
class _FabAction extends StatelessWidget {
  const _FabAction({
    required this.animation,
    required this.icon,

    required this.onPressed,
  });

  final Animation<double> animation;
  final IconData icon;

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    // `SizeTransition` e não só escala: o tamanho precisa sair do layout quando
    // fecha, senão a coluna continuaria alta e empurraria o botão principal
    // para o meio da tela, longe de onde um FAB deve estar.
    return SizeTransition(
      sizeFactor: animation,
      // Ancorada embaixo e à direita, em cima do botão principal: a ação
      // parece sair de dentro dele, e não descer do topo da tela.
      alignment: Alignment.bottomRight,
      child: FadeTransition(
        opacity: animation,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: FloatingActionButton(
            // Sem isto os três FABs desta tela disputam a mesma tag de Hero e o
            // Flutter estoura. O principal fica com a tag padrão, que é a que
            // faz a transição para o FAB da lista de destino.
            heroTag: null,
            onPressed: onPressed,
            child: Icon(icon),
          ),
        ),
      ),
    );
  }
}
