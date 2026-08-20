import 'package:multiple_result/multiple_result.dart';

import '../../core/errors/app_exception.dart';
import '../../core/errors/failure.dart';
import '../../core/network/api_client.dart';
import '../../core/shared/patch.dart';
import '../models/credit_card_model.dart';

/// As cinco operações de `/credit-cards`.
///
/// O cartão não tem vigência nem histórico: o valor dele não é dinheiro que
/// entra, é configuração. Por isso aqui não existe o par reajuste/correção de
/// ganhos — um cartão só é editado, e a edição vale para tudo.
abstract interface class CreditCardRepository {
  /// [month] resolve o `dueDate` de cada cartão (CAR-03). Sem ele os cartões
  /// vêm com `dueDate` null, e a lista não tem o que mostrar de vencimento.
  Future<Result<List<CreditCardModel>, Failure>> list({String? month});

  Future<Result<CreditCardModel, Failure>> getById(String id, {String? month});

  /// Devolve o `id` gerado, que é tudo que o `201` traz.
  Future<Result<String, Failure>> create({
    required String name,
    required int closingDay,
    required int dueDay,
    String? lastDigits,
    int? limitCents,
  });

  /// Edição parcial, com a semântica do CAR-08: **campo ausente não muda nada,
  /// `null` limpa**.
  ///
  /// Os dois campos limpáveis pedem [Patch] justamente para poderem dizer as
  /// três coisas. Os outros três não são anuláveis no backend, então `null`
  /// neles só pode significar "não mexi".
  ///
  /// Corpo vazio volta 400 ("Informe ao menos um campo para atualizar"), então
  /// quem chama confere antes se há algo a mandar.
  Future<Result<bool, Failure>> update(
    String id, {
    String? name,
    int? closingDay,
    int? dueDay,
    Patch<String> lastDigits,
    Patch<int> limitCents,
  });

  /// Recusado com 409 quando há gasto vinculado (CAR-07) — a FK é `RESTRICT`.
  /// Nesse caso o cartão continua lá, e quem chamou mostra a explicação.
  Future<Result<bool, Failure>> delete(String id);
}

class CreditCardRepositoryImpl implements CreditCardRepository {
  CreditCardRepositoryImpl(this._api);

  final ApiClient _api;

  @override
  Future<Result<List<CreditCardModel>, Failure>> list({String? month}) async {
    try {
      final response = await _api.get(
        '/credit-cards',
        queryParameters: {'month': month},
      );
      return Success(Decode.listOf(response.data, CreditCardModel.fromJson));
    } on AppException catch (exception) {
      return Error(Failure.fromException(exception));
    } catch (error, stackTrace) {
      return Error(_serializationFailure(error, stackTrace));
    }
  }

  @override
  Future<Result<CreditCardModel, Failure>> getById(
    String id, {
    String? month,
  }) async {
    try {
      final response = await _api.get(
        '/credit-cards/$id',
        queryParameters: {'month': month},
      );
      return Success(CreditCardModel.fromJson(Decode.object(response.data)));
    } on AppException catch (exception) {
      return Error(Failure.fromException(exception));
    } catch (error, stackTrace) {
      return Error(_serializationFailure(error, stackTrace));
    }
  }

  @override
  Future<Result<String, Failure>> create({
    required String name,
    required int closingDay,
    required int dueDay,
    String? lastDigits,
    int? limitCents,
  }) async {
    try {
      final response = await _api.post(
        '/credit-cards',
        data: {
          'name': name,
          'closingDay': closingDay,
          'dueDay': dueDay,
          // Na criação, opcional que não veio simplesmente não entra no corpo. A
          // ambiguidade do CAR-08 não existe aqui: não há valor anterior para
          // preservar nem para limpar.
          'lastDigits': ?lastDigits,
          'limitCents': ?limitCents,
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
  Future<Result<bool, Failure>> update(
    String id, {
    String? name,
    int? closingDay,
    int? dueDay,
    Patch<String> lastDigits = const Patch.keep(),
    Patch<int> limitCents = const Patch.keep(),
  }) async {
    try {
      // O `?` só escreve a chave quando o valor não é null — para estes três,
      // null é "não mexi". Os dois limpáveis vão logo abaixo, pelo Patch, porque
      // neles null é um valor que precisa chegar ao backend.
      final body = <String, dynamic>{
        'name': ?name,
        'closingDay': ?closingDay,
        'dueDay': ?dueDay,
      };

      lastDigits.writeTo(body, 'lastDigits');
      limitCents.writeTo(body, 'limitCents');

      await _api.patch('/credit-cards/$id', data: body);
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
      await _api.delete('/credit-cards/$id');
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
