import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/di/injector.dart';
import 'firebase_options.dart';

/// `async` desde a Etapa 7: o Firebase precisa estar de pé antes de qualquer
/// tela, porque é dele que sai o token que toda requisição carrega.
Future<void> main() async {
  // Antes do `initializeApp`, e obrigatório: o firebase_core fala com o lado
  // nativo por platform channel, e quem abre esse canal é o binding. Sem esta
  // linha o app morre no start com "Binding has not yet been initialized".
  WidgetsFlutterBinding.ensureInitialized();

  // As opções vêm do `firebase_options.dart`, gerado pelo `flutterfire
  // configure` — não são lidas do `google-services.json` em runtime. Os dois
  // arquivos existem e precisam continuar concordando: o JSON é o que o plugin
  // do Gradle consome em tempo de build.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Antes do runApp: a primeira tela já pode resolver dependência do get_it, e
  // registrar depois daria "Object/factory not registered" no primeiro build.
  setupInjector();

  runApp(const MyApp());
}
