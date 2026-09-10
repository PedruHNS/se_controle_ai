import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_it/get_it.dart';
import 'package:se_controle_ai/core/router/app_router.dart';
import 'package:se_controle_ai/data/services/navigation_service.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/credit_card_repository.dart';
import '../../data/repositories/expense_repository.dart';
import '../../data/repositories/income_repository.dart';
import '../../data/repositories/summary_repository.dart';
import '../../data/repositories/tag_repository.dart';
import '../../features/auth/controller/login_controller.dart';
import '../../features/credit_cards/controller/credit_card_expenses_controller.dart';
import '../../features/credit_cards/controller/credit_card_controller.dart';
import '../../features/expenses/controller/expense_detail_controller.dart';
import '../../features/expenses/controller/expense_form_controller.dart';
import '../../features/expenses/controller/expense_list_controller.dart';
import '../../features/home/controller/home_controller.dart';
import '../../features/incomes/controller/income_detail_controller.dart';
import '../../features/incomes/controller/income_form_controller.dart';
import '../../features/incomes/controller/income_list_controller.dart';
import '../../features/projection/controller/projection_controller.dart';
import '../../features/tags/controller/tag_list_controller.dart';
import '../month/selected_month_service.dart';
import '../network/api_client.dart';
import '../network/dio_factory.dart';
import '../theme/theme_controller.dart';

part 'injector_controllers.dart';
part 'injector_repositories.dart';
part 'injector_services.dart';

final getIt = GetIt.instance;

Future<void> setupInjector() async {
  // Os repositórios antes do Dio, invertendo a ordem de leitura: o Dio agora
  // depende do de autenticação, que é quem sabe o token. Não muda a execução —
  // `lazySingleton` resolve na hora de construir —, mas deixa a dependência
  // visível para quem lê.

  _registerRepositories();
  if (!getIt.isRegistered<Dio>()) {
    getIt.registerLazySingleton<Dio>(
      () => buildDio(auth: getIt<AuthRepository>()),
    );
  }

  if (!getIt.isRegistered<ApiClient>()) {
    getIt.registerSingleton<ApiClient>(
      ApiClient(getIt<Dio>()),
      signalsReady: true,
    );
  }

  _registerServices();

  _registerControllers();
}
