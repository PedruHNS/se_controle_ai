import 'package:flutter/material.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // `.router` e não o construtor normal: é o que entrega a navegação ao
    // go_router. Com `home:` as rotas simplesmente não seriam usadas.
    return MaterialApp.router(
      title: 'Se Controle AI',
      routerConfig: appRouter,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // Segue o sistema, e não uma preferência guardada: guardar exige
      // armazenamento local, que só chega na Fase 10. Enquanto isso, seguir o
      // aparelho é o comportamento que a pessoa já configurou uma vez.
      themeMode: ThemeMode.system,
    );
  }
}
