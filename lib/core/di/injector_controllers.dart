part of 'injector.dart';

/// Os controllers, agrupados por feature.
///
/// **A divisão que se repete em toda feature:** lista é `lazySingleton` com
/// `dispose:` do get_it; formulário e detalhe são `factory`, e quem libera é o
/// `dispose` do `State` da página — factory não aceita o `dispose:` porque o
/// get_it não guarda a instância.
///
/// O motivo de cada lado está nos comentários abaixo, no primeiro caso de cada
/// tipo.
void _registerControllers() {
  // `factory` como os formulários: a tela de login é descartável, e o
  // `dispose` é do `State` da página. lazySingleton aqui manteria a última
  // falha viva depois de sair e voltar — o aviso vermelho de uma tentativa que
  // já passou reaparecendo numa tela limpa.
  getIt.registerFactory<LoginController>(
    () => LoginController(getIt<AuthRepository>()),
  );

  // O tema não pertence a feature nenhuma: quem o lê é o `MaterialApp`, na raiz,
  // e quem o troca é o menu lateral. lazySingleton porque é um por app — dois
  // temas ao mesmo tempo não existem.
  getIt.registerLazySingleton<ThemeController>(
    ThemeController.new,
    dispose: (e) => e.dispose(),
  );

  // O mês selecionado também não pertence a feature nenhuma: a home o troca, e
  // gastos, ganhos, cartões e projeção o leem. lazySingleton pelo motivo mais
  // forte da lista — se fosse `factory`, cada tela receberia uma instância e
  // cada uma voltaria a olhar um mês diferente, que é exatamente o bug que ele
  // existe para fechar.
  getIt.registerLazySingleton<SelectedMonthController>(
    SelectedMonthController.new,
    dispose: (e) => e.dispose(),
  );

  // Controller como lazySingleton, e quem libera os signals é o `dispose:` do
  // get_it — a página não chama `dispose` no controller. O dono da instância é o
  // container, não a tela: sair da home e voltar reaproveita o mesmo resumo já
  // carregado em vez de buscar de novo.
  //
  // A contrapartida é que o estado é único por app. Se algum dia a mesma rota
  // puder ser empilhada duas vezes com meses diferentes, aqui vira
  // `registerFactory` e o `dispose` passa a ser do `State` da página.
  getIt.registerLazySingleton<HomeController>(
    () => HomeController(
      getIt<SummaryRepository>(),
      getIt<SelectedMonthController>(),
    ),
    dispose: (e) => e.dispose(),
  );

  // A projeção é lazySingleton como as listas: o horizonte escolhido sobrevive
  // a sair da tela e voltar, que é o mesmo motivo de o mês da home sobreviver.
  getIt.registerLazySingleton<ProjectionController>(
    () => ProjectionController(
      getIt<SummaryRepository>(),
      getIt<SelectedMonthController>(),
    ),
    dispose: (e) => e.dispose(),
  );

  // Lista com dispose pelo get_it, como as outras.
  getIt.registerLazySingleton<TagListController>(
    () => TagListController(
      repository: getIt<TagRepository>(),
      nav: getIt<NavigationService>(),
    ),
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
    () =>
        IncomeFormController(getIt<IncomeRepository>(), getIt<TagRepository>()),
  );

  getIt.registerFactory<IncomeDetailController>(
    () => IncomeDetailController(getIt<IncomeRepository>()),
  );

  // Cartões seguem a mesma divisão: a lista é lazySingleton com dispose pelo
  // get_it, o formulário é factory porque precisa nascer limpo — e aqui isso
  // pesa mais que em ganhos, já que a mesma tela serve para cadastrar e para
  // editar. Um formulário reaproveitado abriria a edição com o cartão anterior
  // ainda no `_cardOnOpen`, e o diff do CAR-08 sairia contra o cartão errado.
  getIt.registerLazySingleton<CreditCardListController>(
    () => CreditCardListController(
      getIt<CreditCardRepository>(),
      getIt<SelectedMonthController>(),
    ),
    dispose: (e) => e.dispose(),
  );

  getIt.registerFactory<CreditCardFormController>(
    () => CreditCardFormController(getIt<CreditCardRepository>()),
  );

  // Factory pelo mesmo motivo do detalhe de ganho: dois cartões podem estar na
  // pilha, e cada tela fala do seu.
  getIt.registerFactory<CreditCardExpensesController>(
    () => CreditCardExpensesController(
      getIt<ExpenseRepository>(),
      getIt<CreditCardRepository>(),
      getIt<SelectedMonthController>(),
    ),
  );

  // Gastos repetem a divisão de ganhos: lista lazySingleton, formulário e
  // detalhe factory.
  //
  // Os dois últimos dependem **também** do repositório de cartões, e não por
  // acaso: o formulário precisa da lista para o seletor de cartão (é o que
  // fecha o critério da Fase 3), e o detalhe busca o nome do cartão do gasto
  // para não escrever só "No cartão".
  getIt.registerLazySingleton<ExpenseListController>(
    () => ExpenseListController(getIt<ExpenseRepository>()),
    dispose: (e) => e.dispose(),
  );

  getIt.registerFactory<ExpenseFormController>(
    () => ExpenseFormController(
      getIt<ExpenseRepository>(),
      getIt<CreditCardRepository>(),
      getIt<TagRepository>(),
    ),
  );

  getIt.registerFactory<ExpenseDetailController>(
    () => ExpenseDetailController(
      getIt<ExpenseRepository>(),
      getIt<CreditCardRepository>(),
    ),
  );
}
