import 'package:se_controle_ai/core/di/injector.dart';
import 'package:se_controle_ai/data/repositories/income_repository.dart';
import 'package:se_controle_ai/data/repositories/summary_repository.dart';
import 'package:se_controle_ai/features/home/controller/home_controller.dart';
import 'package:se_controle_ai/features/incomes/controller/income_detail_controller.dart';
import 'package:se_controle_ai/features/incomes/controller/income_form_controller.dart';
import 'package:se_controle_ai/features/incomes/controller/income_list_controller.dart';

import 'mocks.dart';

/// Registra as dependências que as telas resolvem, com os repositórios mockados.
///
/// Sem isto, qualquer teste que monte a `HomePage` estoura com "HomeController is
/// not registered" — e usando o `setupInjector` de produção a tela tentaria falar
/// com o backend, deixando o teste dependente do Docker estar de pé.
///
/// **Idempotente de propósito.** O get_it é global e sobrevive entre testes, então
/// chamar isto no `setUp` sem um `reset` no `tearDown` daria "already registered"
/// a partir do segundo teste.
///
/// Os controllers são `registerFactory` aqui, e não o `lazySingleton` da
/// produção: cada teste precisa de um controller novo, senão o estado de um vaza
/// para o próximo. Devolve o mock para o teste ajustar o `when`.
MockSummaryRepository setupTestInjector() {
  final repository = summaryRepositoryMock();

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

/// O mesmo para as telas de ganhos.
MockIncomeRepository setupIncomeTestInjector({MockIncomeRepository? mock}) {
  final repository = mock ?? incomeRepositoryMock();

  if (getIt.isRegistered<IncomeRepository>()) {
    getIt.unregister<IncomeRepository>();
  }
  if (getIt.isRegistered<IncomeListController>()) {
    getIt.unregister<IncomeListController>();
  }
  if (getIt.isRegistered<IncomeFormController>()) {
    getIt.unregister<IncomeFormController>();
  }
  if (getIt.isRegistered<IncomeDetailController>()) {
    getIt.unregister<IncomeDetailController>();
  }

  getIt
    ..registerSingleton<IncomeRepository>(repository)
    ..registerFactory<IncomeListController>(
      () => IncomeListController(getIt<IncomeRepository>()),
    )
    ..registerFactory<IncomeFormController>(
      () => IncomeFormController(getIt<IncomeRepository>()),
    )
    ..registerFactory<IncomeDetailController>(
      () => IncomeDetailController(getIt<IncomeRepository>()),
    );

  return repository;
}
