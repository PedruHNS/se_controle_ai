part of 'injector.dart';

void _registerServices() {
  if (!getIt.isRegistered<NavigationService>()) {
    final router = appRouter;
    getIt.registerSingleton<NavigationService>(NavigationService(router));
  }

  // O mês selecionado não pertence a feature nenhuma: a home o troca, e gastos,
  // ganhos, cartões e projeção o leem. Estava com os controllers enquanto era
  // um — mora aqui desde que virou service.
  //
  // lazySingleton pelo motivo mais forte da lista: se fosse `factory`, cada
  // tela receberia uma instância e cada uma voltaria a olhar um mês diferente,
  // que é exatamente o bug que ele existe para fechar.
  if (!getIt.isRegistered<SelectedMonthService>()) {
    getIt.registerLazySingleton<SelectedMonthService>(
      SelectedMonthService.new,
      dispose: (e) => e.dispose(),
    );
  }
}
