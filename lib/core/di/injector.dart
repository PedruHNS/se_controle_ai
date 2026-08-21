import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

import '../../data/repositories/credit_card_repository.dart';
import '../../data/repositories/expense_repository.dart';
import '../../data/repositories/income_repository.dart';
import '../../data/repositories/summary_repository.dart';
import '../../data/repositories/tag_repository.dart';
import '../../features/credit_cards/controller/credit_card_expenses_controller.dart';
import '../../features/credit_cards/controller/credit_card_form_controller.dart';
import '../../features/credit_cards/controller/credit_card_list_controller.dart';
import '../../features/expenses/controller/expense_detail_controller.dart';
import '../../features/expenses/controller/expense_form_controller.dart';
import '../../features/expenses/controller/expense_list_controller.dart';
import '../../features/home/controller/home_controller.dart';
import '../../features/incomes/controller/income_detail_controller.dart';
import '../../features/incomes/controller/income_form_controller.dart';
import '../../features/incomes/controller/income_list_controller.dart';
import '../../features/projection/controller/projection_controller.dart';
import '../../features/tags/controller/tag_list_controller.dart';
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

  getIt.registerLazySingleton<CreditCardRepository>(
    () => CreditCardRepositoryImpl(getIt<ApiClient>()),
  );

  getIt.registerLazySingleton<ExpenseRepository>(
    () => ExpenseRepositoryImpl(getIt<ApiClient>()),
  );

  getIt.registerLazySingleton<TagRepository>(
    () => HttpTagRepository(getIt<ApiClient>()),
  );

  // Lista com dispose pelo get_it, como as outras.
  getIt.registerLazySingleton<TagListController>(
    () => TagListController(getIt<TagRepository>()),
    dispose: (e) => e.dispose(),
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
    () => IncomeFormController(getIt<IncomeRepository>(), getIt<TagRepository>()),
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
    () => CreditCardListController(getIt<CreditCardRepository>()),
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
    ),
  );

  // A projeção é lazySingleton como as outras listas: o horizonte escolhido
  // sobrevive a sair da tela e voltar, que é o mesmo motivo de o mês da home
  // sobreviver.
  getIt.registerLazySingleton<ProjectionController>(
    () => ProjectionController(getIt<SummaryRepository>()),
    dispose: (e) => e.dispose(),
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

/// Limpa tudo. Necessário entre testes, senão o registro de um vaza no outro.
// Future<void> resetInjector() => getIt.reset();
