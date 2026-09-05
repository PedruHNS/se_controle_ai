import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// A sombra dos cards de lista, em um lugar só.
///
/// A cor vem do tema e não é fixa aqui: no claro é o índigo do app a 10%, no
/// escuro é preto mais opaco. Índigo translúcido sobre um fundo `#13121C` não
/// aparece — a sombra simplesmente sumia, e o card ficava colado no fundo.
class CustomBoxShadowWidget extends StatelessWidget {
  final Widget child;
  const CustomBoxShadowWidget({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).appColors.cardShadow,
            spreadRadius: 0,
            blurRadius: 40,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }
}
