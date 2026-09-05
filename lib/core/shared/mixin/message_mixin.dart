import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:se_controle_ai/core/config/globals.dart';
import 'package:se_controle_ai/core/theme/app_theme.dart';

/// Os dois toasts do app — erro e sucesso.
///
/// A cor vem do tema e não é fixa: o toast é a mesma superfície dos cards de
/// lista, pelo mesmo motivo. Antes disso o fundo era `Colors.white` escrito à
/// mão, e no tema escuro sobrava um retângulo branco com o texto do tema
/// escuro por cima — claro sobre claro, ilegível justamente na hora em que o
/// app tem algo a dizer.
mixin MessageMixin<T extends StatelessWidget> {
  void toastError(String erro) {
    _show(
      icon: const Icon(Icons.cancel, size: 28.0, color: Colors.red),
      message: erro,
      duration: const Duration(seconds: 3),
    );
  }

  void toastSucess(
    String msg, {
    FlushbarPosition? position,
    Duration? duration,
  }) {
    _show(
      icon: const Icon(Icons.check_circle, size: 28.0, color: Colors.blue),
      message: msg,
      position: position ?? FlushbarPosition.BOTTOM,
      duration: duration ?? const Duration(seconds: 3),
    );
  }

  /// O corpo comum dos dois. O contexto sai do `navigatorKey` porque o toast é
  /// disparado de controller, que não tem `BuildContext` próprio — e é dele que
  /// vem o tema, então sem contexto não há o que pintar nem onde mostrar.
  void _show({
    required Icon icon,
    required String message,
    required Duration duration,
    FlushbarPosition? position,
  }) {
    final context = Globals.navigatorKey.currentContext;
    if (context == null) return;

    final theme = Theme.of(context);

    Flushbar(
      boxShadows: [
        BoxShadow(
          color: theme.appColors.cardShadow,
          spreadRadius: 0,
          blurRadius: 40,
          offset: const Offset(0, 1),
        ),
      ],
      flushbarPosition: position ?? FlushbarPosition.BOTTOM,
      backgroundColor: theme.appColors.card,
      borderRadius: BorderRadius.circular(12),
      margin: const EdgeInsets.all(15),
      messageText: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          icon,
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              message,
              // A cor é explícita e não herdada: o `messageText` do Flushbar
              // fica fora da árvore da tela, e o `DefaultTextStyle` que ele
              // pega não é o do tema do app.
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 14.5,
                color: theme.colorScheme.onSurface,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      duration: duration,
    ).show(context);
  }
}
