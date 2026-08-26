import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_it/get_it.dart';

import '../../data/repositories/auth_repository.dart';
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
import '../month/selected_month_controller.dart';
import '../network/api_client.dart';
import '../network/dio_factory.dart';
import '../theme/theme_controller.dart';

/// O registro é dividido em `part`, e não em arquivos separados com import: os
/// dois lados registram no mesmo `getIt` e usam as mesmas dependências, então
/// continuam sendo **uma biblioteca só** — o que muda é onde cada trecho mora.
///
/// A consequência de usar `part` é que os imports ficam todos aqui: um `part`
/// não tem import próprio. É o preço de as funções privadas (`_register…`)
/// continuarem privadas e ainda assim visíveis entre os arquivos.
part 'injector_controllers.dart';
part 'injector_repositories.dart';

final getIt = GetIt.instance;

/// Registra as dependências. Chamar em `main()` antes de `runApp`.
///
/// `registerLazySingleton` e não `registerSingleton`: nada é construído até o
/// primeiro uso, então o start do app não paga por dependência que talvez não
/// seja usada naquela sessão.
///
/// A ordem importa só na leitura, não na execução: o `getIt` resolve na hora de
/// construir, então repositório registrado depois do controller que o usa
/// funciona igual. Aqui vêm primeiro porque é assim que se lê — rede,
/// repositório, controller.
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

  _registerRepositories();
  _registerControllers();
}

/// Limpa tudo. Necessário entre testes, senão o registro de um vaza no outro.
// Future<void> resetInjector() => getIt.reset();
