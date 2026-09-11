import 'package:multiple_result/multiple_result.dart';

import '../../core/errors/app_exception.dart';
import '../../core/errors/failure.dart';
import '../../core/errors/serialization_failure.dart';
import '../../core/network/api_client.dart';
import '../models/dashboard_model.dart';

/// A tela do dashboard inteira, numa requisição só.
///
/// Uma rota, um método: `GET /dashboard` devolve os oito blocos juntos, e é de
/// propósito — `byTag` é um `GROUP BY` de uma linha em SQL, `history` sem rota
/// seriam seis requisições, e `byNature` nem é computável aqui.
abstract interface class DashboardRepository {
  /// [month] é `YYYY-MM` e é **obrigatório**, embora a rota aceite ausência.
  /// Sem ele o backend responde a competência do relógio **dele** (DSH-01), e
  /// a tela mostraria um mês que não é o que o app selecionou — erro que não
  /// aparece em teste nenhum, só na virada do mês.
  Future<Result<DashboardModel, Failure>> getDashboard({required String month});
}

class DashboardRepositoryImpl implements DashboardRepository {
  DashboardRepositoryImpl(this._api);

  final ApiClient _api;

  @override
  Future<Result<DashboardModel, Failure>> getDashboard({
    required String month,
  }) async {
    try {
      final response = await _api.get(
        '/dashboard',
        queryParameters: {'month': month},
      );
      return Success(DashboardModel.fromJson(Decode.object(response.data)));
    } on AppException catch (exception) {
      return Error(Failure.fromException(exception));
    } catch (error, stackTrace) {
      return Error(serializationFailure(error, stackTrace));
    }
  }
}
