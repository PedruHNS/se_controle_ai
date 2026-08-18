import 'package:se_controle_ai/core/di/injector.dart';
import 'package:se_controle_ai/data/repositories/summary_repository.dart';
import 'package:se_controle_ai/features/home/controller/home_controller.dart';

import 'fake_summary_repository.dart';

/// Registra as dependências que as telas resolvem, com repositório falso.
///
/// Sem isto, qualquer teste que monte a `HomePage` estoura com "HomeController is
/// not registered" — e usando o `setupInjector` de produção a tela tentaria falar
/// com o backend, deixando o teste dependente do Docker estar de pé.
///
/// **Idempotente de propósito.** O get_it é global e sobrevive entre testes, então
/// chamar isto no `setUp` sem um `reset` no `tearDown` daria "already registered"
/// a partir do segundo teste. Limpando o registro anterior aqui, funciona nos dois
/// casos — com ou sem `resetInjector`.
///
/// Devolve um fake novo, para o teste ajustar a resposta. Precisa ser novo: o
/// `requestedMonths` acumula, e um fake reaproveitado carregaria as chamadas do
/// teste anterior.
FakeSummaryRepository setupTestInjector() {
  final repository = FakeSummaryRepository();

  if (getIt.isRegistered<SummaryRepository>()) {
    getIt.unregister<SummaryRepository>();
  }
  if (getIt.isRegistered<HomeController>()) {
    getIt.unregister<HomeController>();
  }

  getIt
    ..registerSingleton<SummaryRepository>(repository)
    ..registerFactory<HomeController>(
      () => HomeController(getIt<SummaryRepository>()),
    );

  return repository;
}
