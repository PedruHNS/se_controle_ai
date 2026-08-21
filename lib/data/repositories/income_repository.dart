import 'package:multiple_result/multiple_result.dart';

import '../../core/errors/app_exception.dart';
import '../../core/errors/failure.dart';
import '../../core/network/api_client.dart';
import '../models/income_model.dart';

/// As sete operações de `/incomes`.
///
/// **Reajuste e correção são métodos separados de propósito.** No backend são
/// rotas diferentes com semânticas opostas — [adjust] preserva os meses
/// anteriores, [correct] reescreve desde o início — e uma assinatura única com
/// um `bool` esconderia justamente a decisão que o usuário precisa tomar.
abstract interface class IncomeRepository {
  /// Sem [month], devolve todos os ganhos com o valor da vigência mais recente.
  /// Com [month], só os que vigem naquela competência, com o valor de lá.
  Future<Result<List<IncomeModel>, Failure>> list({String? month});

  Future<Result<IncomeModel, Failure>> getById(String id, {String? month});

  /// Devolve o `id` gerado, que é tudo que o `201` traz.
  Future<Result<String, Failure>> create({
    required String description,
    required int amountCents,
    required String startMonth,

    /// TAG-07: opcional no ganho, ao contrário do gasto.
    String? tagId,
    bool recurring = true,
  });

  /// Reajuste: fecha a vigência atual em [effectiveFrom] - 1 mês e abre uma
  /// nova. O que foi recebido antes disso continua valendo.
  Future<Result<bool, Failure>> adjust(
    String id, {
    required int amountCents,
    required String effectiveFrom,
  });

  /// Correção: o valor estava errado desde o começo da vigência atual, e passa
  /// a valer também nos meses já passados dela.
  Future<Result<bool, Failure>> correct(String id, {required int amountCents});

  /// Encerramento: [lastMonth] é o último mês recebido.
  Future<Result<bool, Failure>> close(String id, {required String lastMonth});

  /// Apaga o ganho e todo o histórico. É "cadastrei errado", não "parei de
  /// receber" — para o segundo caso existe [close].
  Future<Result<bool, Failure>> delete(String id);
}

class IncomeRepositoryImpl implements IncomeRepository {
  IncomeRepositoryImpl(this._api);

  final ApiClient _api;

  @override
  Future<Result<List<IncomeModel>, Failure>> list({String? month}) async {
    try {
      final response = await _api.get(
        '/incomes',
        queryParameters: {'month': month},
      );
      return Success(Decode.listOf(response.data, IncomeModel.fromJson));
    } on AppException catch (exception) {
      return Error(Failure.fromException(exception));
    } catch (error, stackTrace) {
      return Error(_serializationFailure(error, stackTrace));
    }
  }

  @override
  Future<Result<IncomeModel, Failure>> getById(
    String id, {
    String? month,
  }) async {
    try {
      final response = await _api.get(
        '/incomes/$id',
        queryParameters: {'month': month},
      );
      return Success(IncomeModel.fromJson(Decode.object(response.data)));
    } on AppException catch (exception) {
      return Error(Failure.fromException(exception));
    } catch (error, stackTrace) {
      return Error(_serializationFailure(error, stackTrace));
    }
  }

  @override
  Future<Result<String, Failure>> create({
    required String description,
    required int amountCents,
    required String startMonth,
    String? tagId,
    bool recurring = true,
  }) async {
    try {
      final response = await _api.post(
        '/incomes',
        data: {
          'description': description,
          'tagId': ?tagId,
          'amountCents': amountCents,
          'startMonth': startMonth,
          'recurring': recurring,
        },
      );
      return Success(Decode.object(response.data)['id'] as String);
    } on AppException catch (exception) {
      return Error(Failure.fromException(exception));
    } catch (error, stackTrace) {
      return Error(_serializationFailure(error, stackTrace));
    }
  }

  @override
  Future<Result<bool, Failure>> adjust(
    String id, {
    required int amountCents,
    required String effectiveFrom,
  }) async {
    try {
      await _api.post(
        '/incomes/$id/adjustments',
        data: {'amountCents': amountCents, 'effectiveFrom': effectiveFrom},
      );
      return Success(true);
    } on AppException catch (exception) {
      return Error(Failure.fromException(exception));
    } catch (error, stackTrace) {
      return Error(_serializationFailure(error, stackTrace));
    }
  }

  @override
  Future<Result<bool, Failure>> correct(
    String id, {
    required int amountCents,
  }) async {
    try {
      await _api.patch(
        '/incomes/$id/amount',
        data: {'amountCents': amountCents},
      );
      return Success(true);
    } on AppException catch (exception) {
      return Error(Failure.fromException(exception));
    } catch (error, stackTrace) {
      return Error(_serializationFailure(error, stackTrace));
    }
  }

  @override
  Future<Result<bool, Failure>> close(
    String id, {
    required String lastMonth,
  }) async {
    try {
      await _api.post('/incomes/$id/closure', data: {'lastMonth': lastMonth});
      return Success(true);
    } on AppException catch (exception) {
      return Error(Failure.fromException(exception));
    } catch (error, stackTrace) {
      return Error(_serializationFailure(error, stackTrace));
    }
  }

  @override
  Future<Result<bool, Failure>> delete(String id) async {
    try {
      await _api.delete('/incomes/$id');
      return Success(true);
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
