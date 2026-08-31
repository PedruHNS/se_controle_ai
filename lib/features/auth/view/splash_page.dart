import 'package:flutter/material.dart';

/// A espera dos primeiros quadros, enquanto o Firebase diz se há sessão.
///
/// **Deliberadamente sem marca e sem texto.** Ela aparece por uma fração de
/// segundo em quem já está logado, e some antes de ser lida — logo, palavra
/// nenhuma aqui chega a ser lida por ninguém. O que se percebe é a ausência do
/// piscar da tela de login, que era o problema.
///
/// Nada de `Scaffold` com `AppBar`: uma barra que aparece e desaparece em dois
/// quadros é mais visível do que a espera que ela decoraria.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        // `key` porque é isto que o teste procura: um `CircularProgressIndicator`
        // solto existe em meia dúzia de telas, e `findsOneWidget` sobre o tipo
        // acharia o da tela errada no dia em que o splash não fosse construído.
        child: CircularProgressIndicator(key: Key('splash-espera')),
      ),
    );
  }
}
