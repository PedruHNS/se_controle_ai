import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';

import 'core/di/injector.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = getIt<ThemeController>();

    // O `SignalBuilder` fica **em volta do MaterialApp**, e não dentro de uma
    // tela: trocar o tema repinta o app inteiro, inclusive o que está empilhado
    // atrás do menu lateral.
    return SignalBuilder(
      builder: (context) => MaterialApp.router(
        // `.router` e não o construtor normal: é o que entrega a navegação ao
        // go_router. Com `home:` as rotas simplesmente não seriam usadas.
        title: 'Se Controle AI',
        routerConfig: appRouter,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        // O padrão é seguir o sistema; o menu lateral troca por esta sessão. A
        // escolha não sobrevive a fechar o app — guardá-la exige armazenamento
        // local, que chega na Fase 10.
        themeMode: theme.mode.value,
      ),
    );
  }
}
