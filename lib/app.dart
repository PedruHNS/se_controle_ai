import 'package:flutter/material.dart';

import 'core/router/app_router.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // `.router` e não o construtor normal: é o que entrega a navegação ao
    // go_router. Com `home:` as rotas simplesmente não seriam usadas.
    return MaterialApp.router(
      title: 'Se Controle AI',
      routerConfig: appRouter,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
    );
  }
}
