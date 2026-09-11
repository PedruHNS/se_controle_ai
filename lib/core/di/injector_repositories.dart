part of 'injector.dart';

/// Os repositórios: um por recurso do backend, todos sobre o mesmo
/// [ApiClient].
///
/// Todos `lazySingleton` e sem `dispose:` — repositório não guarda estado, só
/// traduz HTTP em `Result`. Não há o que liberar, e ter dois do mesmo tipo não
/// quebraria nada; é singleton por economia, não por regra.
void _registerRepositories() {
  // Fora do padrão dos demais, e por dois motivos: não fala com a nossa API, e
  // é o único que outra peça de infraestrutura consome — o interceptor do Dio
  // pede o token a ele antes de cada requisição.
  getIt.registerLazySingleton<AuthRepository>(
    () =>
        FirebaseAuthRepository(FirebaseAuth.instance, PlatformGoogleIdentity()),
  );

  getIt.registerLazySingleton<SummaryRepository>(
    () => SummaryRepositoryImpl(getIt<ApiClient>()),
  );

  getIt.registerLazySingleton<IncomeRepository>(
    () => IncomeRepositoryImpl(getIt<ApiClient>()),
  );

  getIt.registerLazySingleton<CreditCardRepository>(
    () => CreditCardRepositoryImpl(getIt<ApiClient>()),
  );

  getIt.registerLazySingleton<ExpenseRepository>(
    () => ExpenseRepositoryImpl(getIt<ApiClient>()),
  );

  getIt.registerLazySingleton<DashboardRepository>(
    () => DashboardRepositoryImpl(getIt<ApiClient>()),
  );

  getIt.registerLazySingleton<TagRepository>(
    () => HttpTagRepository(getIt<ApiClient>()),
  );
}
