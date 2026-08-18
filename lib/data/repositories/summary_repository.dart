import 'package:multiple_result/multiple_result.dart';

import '../../core/errors/app_exception.dart';
import '../../core/errors/failure.dart';
import '../../core/network/api_client.dart';
import '../models/month_projection_model.dart';
import '../models/monthly_summary_model.dart';

/// Interface e não classe concreta direto: é o que permite o teste do controller
/// injetar um repositório falso sem subir Dio nem servidor.
abstract interface class SummaryRepository {
  /// Resumo do mês. Sem [month], o backend usa a competência corrente.
  Future<Result<MonthlySummaryModel, Failure>> getMonthly({String? month});

  /// Projeção de saldo a partir de [from], por [months] meses (1 a 60).
  Future<Result<List<MonthProjectionModel>, Failure>> getProjection({
    String? from,
    int months = 12,
  });
}

class SummaryRepositoryImpl implements SummaryRepository {
  SummaryRepositoryImpl(this._api);

  final ApiClient _api;

  @override
  Future<Result<MonthlySummaryModel, Failure>> getMonthly({
    String? month,
  }) async {
    try {
      final response = await _api.get(
        '/summary',
        queryParameters: {'month': month},
      );
      return Success(
        MonthlySummaryModel.fromJson(Decode.object(response.data)),
      );
    } on AppException catch (exception) {
      return Error(Failure.fromException(exception));
    } catch (error, stackTrace) {
      return Error(_serializationFailure(error, stackTrace));
    }
  }

  @override
  Future<Result<List<MonthProjectionModel>, Failure>> getProjection({
    String? from,
    int months = 12,
  }) async {
    try {
      final response = await _api.get(
        '/summary/projection',
        queryParameters: {'from': from, 'months': months},
      );
      return Success(
        Decode.listOf(response.data, MonthProjectionModel.fromJson),
      );
    } on AppException catch (exception) {
      return Error(Failure.fromException(exception));
    } catch (error, stackTrace) {
      return Error(_serializationFailure(error, stackTrace));
    }
  }

  /// O decode fica dentro do `try` de propósito: `on AppException` não pega o
  /// `TypeError` de um cast, então um campo que mudou de tipo no backend viraria
  /// crash em vez de erro tratado. Este `catch` é a rede para isso.
  Failure _serializationFailure(Object error, StackTrace stackTrace) =>
      Failure.fromException(
        SerializationException(
          message: '$error',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
}
