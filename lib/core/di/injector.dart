import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

import '../../data/repositories/income_repository.dart';
import '../../data/repositories/summary_repository.dart';
import '../../features/home/controller/home_controller.dart';
import '../../features/incomes/controller/income_detail_controller.dart';
import '../../features/incomes/controller/income_form_controller.dart';
import '../../features/incomes/controller/income_list_controller.dart';
import '../network/api_client.dart';
import '../network/dio_factory.dart';

final getIt = GetIt.instance;

/// Registra as dependências. Chamar em `main()` antes de `runApp`.
///
/// `registerLazySingleton` e não `registerSingleton`: nada é construído até o
/// primeiro uso, então o start do app não paga por dependência que talvez não
/// seja usada naquela sessão.
///
/// [baseUrl] existe para teste — em produção vem do `AppConfig`.
void setupInjector() {
  if (!getIt.isRegistered<Dio>()) {
    getIt.registerLazySingleton<Dio>(() => buildDio());
  }

  if (!getIt.isRegistered<ApiClient>()) {
    getIt.registerSingleton<ApiClient>(
      ApiClient(getIt<Dio>()),
      signalsReady: true,
    );
  }

  getIt.registerLazySingleton<SummaryRepository>(
    () => SummaryRepositoryImpl(getIt<ApiClient>()),
  );

  getIt.registerLazySingleton<IncomeRepository>(
    () => IncomeRepositoryImpl(getIt<ApiClient>()),
  );

  // Controller como lazySingleton, e quem libera os signals é o `dispose:` do
  // get_it — a página não chama `dispose` no controller. O dono da instância é o
  // container, não a tela: sair da home e voltar reaproveita o mesmo controller,
  // então o mês selecionado sobrevive à navegação em vez de recomeçar no atual.
  //
  // A contrapartida é que o estado é único por app. Se algum dia a mesma rota
  // puder ser empilhada duas vezes com meses diferentes, aqui vira
  // `registerFactory` e o `dispose` passa a ser do `State` da página.
  getIt.registerLazySingleton<HomeController>(
    () => HomeController(getIt<SummaryRepository>()),
    dispose: (e) => e.dispose(),
  );

  // A lista segue a regra do HomeController: uma tela só, estado que vale a
  // pena preservar entre idas e vindas, get_it libera.
  getIt.registerLazySingleton<IncomeListController>(
    () => IncomeListController(getIt<IncomeRepository>()),
    dispose: (e) => e.dispose(),
  );

  // Formulário e detalhe são o caso que a regra prevê como exceção: estado por
  // instância, não por app. Um formulário reaberto precisa nascer limpo, e dois
  // detalhes na pilha falam de ganhos diferentes. Por isso factory — e, como
  // factory não aceita o `dispose:` do get_it, quem libera é o `dispose` da
  // página.
  //
  // O detalhe recebe o id pelo `start`, e não pelo registro: id é dado de rota,
  // e quem o conhece é a view.
  getIt.registerFactory<IncomeFormController>(
    () => IncomeFormController(getIt<IncomeRepository>()),
  );

  getIt.registerFactory<IncomeDetailController>(
    () => IncomeDetailController(getIt<IncomeRepository>()),
  );
}

/// Limpa tudo. Necessário entre testes, senão o registro de um vaza no outro.
// Future<void> resetInjector() => getIt.reset();
