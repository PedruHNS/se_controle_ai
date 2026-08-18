import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

import '../../data/repositories/summary_repository.dart';
import '../../features/home/controller/home_controller.dart';
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

  // Controller usa registerFactory, não singleton: cada tela precisa da própria
  // instância. Como singleton, dois pushes da mesma rota compartilhariam estado
  // — e o `dispose` do primeiro deixaria o segundo com signal morto.

  getIt.registerLazySingleton<HomeController>(
    () => HomeController(getIt<SummaryRepository>()),
    dispose: (e) => e.dispose(),
  );
}

/// Limpa tudo. Necessário entre testes, senão o registro de um vaza no outro.
// Future<void> resetInjector() => getIt.reset();
