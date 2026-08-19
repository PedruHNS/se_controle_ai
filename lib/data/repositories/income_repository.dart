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
  Future<Result<List<IncomeModel>, Failure>> list({String? month}) =>
      _guard(() async {
        final response = await _api.get(
          '/incomes',
          queryParameters: {'month': month},
        );
        return Decode.listOf(response.data, IncomeModel.fromJson);
      });

  @override
  Future<Result<IncomeModel, Failure>> getById(String id, {String? month}) =>
      _guard(() async {
        final response = await _api.get(
          '/incomes/$id',
          queryParameters: {'month': month},
        );
        return IncomeModel.fromJson(Decode.object(response.data));
      });

  @override
  Future<Result<String, Failure>> create({
    required String description,
    required int amountCents,
    required String startMonth,
    bool recurring = true,
  }) => _guard(() async {
    final response = await _api.post(
      '/incomes',
      data: {
        'description': description,
        'amountCents': amountCents,
        'startMonth': startMonth,
        'recurring': recurring,
      },
    );
    return Decode.object(response.data)['id'] as String;
  });

  @override
  Future<Result<bool, Failure>> adjust(
    String id, {
    required int amountCents,
    required String effectiveFrom,
  }) => _guard(() async {
    await _api.post(
      '/incomes/$id/adjustments',
      data: {'amountCents': amountCents, 'effectiveFrom': effectiveFrom},
    );
    return true;
  });

  @override
  Future<Result<bool, Failure>> correct(
    String id, {
    required int amountCents,
  }) => _guard(() async {
    await _api.patch('/incomes/$id/amount', data: {'amountCents': amountCents});
    return true;
  });

  @override
  Future<Result<bool, Failure>> close(String id, {required String lastMonth}) =>
      _guard(() async {
        await _api.post('/incomes/$id/closure', data: {'lastMonth': lastMonth});
        return true;
      });

  @override
  Future<Result<bool, Failure>> delete(String id) => _guard(() async {
    await _api.delete('/incomes/$id');
    return true;
  });

  /// Os sete métodos têm o mesmo esqueleto de erro, então ele vive aqui em vez
  /// de sete `try/catch` iguais. O decode fica **dentro** do `try` pelo mesmo
  /// motivo de sempre: `on AppException` não pega o `TypeError` de um cast.
  Future<Result<T, Failure>> _guard<T>(Future<T> Function() call) async {
    try {
      return Success(await call());
    } on AppException catch (exception) {
      return Error(Failure.fromException(exception));
    } catch (error, stackTrace) {
      return Error(
        Failure.fromException(
          SerializationException(
            message: '$error',
            cause: error,
            stackTrace: stackTrace,
          ),
        ),
      );
    }
  }
}
