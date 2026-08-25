part of 'injector.dart';

/// Os repositórios: um por recurso do backend, todos sobre o mesmo
/// [ApiClient].
///
/// Todos `lazySingleton` e sem `dispose:` — repositório não guarda estado, só
/// traduz HTTP em `Result`. Não há o que liberar, e ter dois do mesmo tipo não
/// quebraria nada; é singleton por economia, não por regra.
void _registerRepositories() {
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

  getIt.registerLazySingleton<TagRepository>(
    () => HttpTagRepository(getIt<ApiClient>()),
  );
}
