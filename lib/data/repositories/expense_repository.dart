import 'package:multiple_result/multiple_result.dart';

import '../../core/errors/app_exception.dart';
import '../../core/errors/failure.dart';
import '../../core/network/api_client.dart';
import '../../core/shared/patch.dart';
import '../models/expense_model.dart';

/// As operações de `/expenses` que a Fase 4 usa.
///
/// **Reajuste, correção e encerramento existem aqui pelo mesmo motivo que em
/// ganhos**: no backend são rotas com semânticas opostas — [adjust] preserva os
/// meses anteriores, [correct] reescreve a vigência atual inteira — e uma
/// assinatura única com um `bool` esconderia justamente a decisão que o usuário
/// precisa tomar (CONC-11).
///
/// Ficam de fora, por pertencerem ao gasto parcelado (Fase 5): a criação com
/// `type: INSTALLMENT`, o reparcelamento e a quitação. A interface cresce
/// quando a tela existir; declará-los agora seria contrato sem consumidor.
abstract interface class ExpenseRepository {
  /// Sem [month], devolve **todos** os gastos, e cada um vem com
  /// `amountCents: null` — o valor sai do `history`. Com [month], só os
  /// cobrados naquela competência, já com o valor de lá (GFX-10).
  ///
  /// A lista da tela busca sem competência de propósito: esconder um gasto
  /// encerrado porque hoje é dezembro deixaria o usuário sem como consultar ou
  /// apagar o que cadastrou. Quem recorta por mês é a home, em `/summary`.
  Future<Result<List<ExpenseModel>, Failure>> list({
    String? month,
    ExpenseType? type,
    PaymentMethod? paymentMethod,
    String? creditCardId,
  });

  Future<Result<ExpenseModel, Failure>> getById(String id, {String? month});

  /// Cria um gasto **fixo** — recorrente ou de mês único, conforme [recurring]
  /// (GFX-03). Devolve o `id` gerado, que é tudo que o `201` traz.
  ///
  /// [creditCardId] é obrigatório quando [paymentMethod] é cartão e proibido
  /// quando é débito; quem recusa a combinação errada é o backend, com 422
  /// (GFX-01), porque a regra precisa existir num lugar só.
  Future<Result<String, Failure>> createFixed({
    required String description,
    required PaymentMethod paymentMethod,
    required int amountCents,
    required String startMonth,
    String? category,
    String? creditCardId,
    bool recurring = true,
  });

  /// Dados cadastrais — descrição, categoria, forma de pagamento, cartão.
  /// **Não são versionados** (GFX-06): mudá-los muda a exibição de todos os
  /// meses, inclusive os passados, e isso é intencional.
  ///
  /// Os dois campos anuláveis pedem [Patch] pelo mesmo motivo do CAR-08 do
  /// cartão: campo ausente não muda nada, `null` limpa, e um `String?` não diz
  /// as duas coisas. Trocar para débito limpa o cartão sozinho no backend
  /// (GFX-07), então nesse caso não é preciso mandar `creditCardId: null`.
  ///
  /// Corpo vazio volta 400, então quem chama confere antes se há o que mandar.
  Future<Result<bool, Failure>> updateDetails(
    String id, {
    String? description,
    PaymentMethod? paymentMethod,
    Patch<String> category,
    Patch<String> creditCardId,
  });

  /// Reajuste: fecha a vigência atual em [effectiveFrom] - 1 mês e abre outra.
  /// O que foi pago antes disso continua valendo.
  Future<Result<bool, Failure>> adjust(
    String id, {
    required int amountCents,
    required String effectiveFrom,
  });

  /// Correção: o valor estava errado desde o começo da vigência atual, e passa
  /// a valer também nos meses já passados dela.
  Future<Result<bool, Failure>> correct(String id, {required int amountCents});

  /// Encerramento: [lastMonth] é a última competência cobrada.
  Future<Result<bool, Failure>> close(String id, {required String lastMonth});

  /// Apaga o gasto e todas as vigências. É "cadastrei errado", não "cancelei o
  /// serviço" — para o segundo caso existe [close] (GFX-08).
  Future<Result<bool, Failure>> delete(String id);
}

class ExpenseRepositoryImpl implements ExpenseRepository {
  ExpenseRepositoryImpl(this._api);

  final ApiClient _api;

  @override
  Future<Result<List<ExpenseModel>, Failure>> list({
    String? month,
    ExpenseType? type,
    PaymentMethod? paymentMethod,
    String? creditCardId,
  }) async {
    try {
      final response = await _api.get(
        '/expenses',
        queryParameters: {
          'month': month,
          'type': type?.wire,
          'paymentMethod': paymentMethod?.wire,
          'creditCardId': creditCardId,
        },
      );
      return Success(Decode.listOf(response.data, ExpenseModel.fromJson));
    } on AppException catch (exception) {
      return Error(Failure.fromException(exception));
    } catch (error, stackTrace) {
      return Error(_serializationFailure(error, stackTrace));
    }
  }

  @override
  Future<Result<ExpenseModel, Failure>> getById(
    String id, {
    String? month,
  }) async {
    try {
      final response = await _api.get(
        '/expenses/$id',
        queryParameters: {'month': month},
      );
      return Success(ExpenseModel.fromJson(Decode.object(response.data)));
    } on AppException catch (exception) {
      return Error(Failure.fromException(exception));
    } catch (error, stackTrace) {
      return Error(_serializationFailure(error, stackTrace));
    }
  }

  @override
  Future<Result<String, Failure>> createFixed({
    required String description,
    required PaymentMethod paymentMethod,
    required int amountCents,
    required String startMonth,
    String? category,
    String? creditCardId,
    bool recurring = true,
  }) async {
    try {
      final response = await _api.post(
        '/expenses',
        data: {
          'type': ExpenseType.fixed.wire,
          'description': description,
          'category': category,
          'paymentMethod': paymentMethod.wire,
          'creditCardId': creditCardId,
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
  Future<Result<bool, Failure>> updateDetails(
    String id, {
    String? description,
    PaymentMethod? paymentMethod,
    Patch<String> category = const Patch.keep(),
    Patch<String> creditCardId = const Patch.keep(),
  }) async {
    try {
      // O `?` só escreve a chave quando o valor não é null — para estes dois,
      // null é "não mexi". Os dois anuláveis vão pelo Patch, logo abaixo, porque
      // neles null é um valor que precisa chegar ao backend.
      final body = <String, dynamic>{
        'description': ?description,
        'paymentMethod': ?paymentMethod?.wire,
      };

      category.writeTo(body, 'category');
      creditCardId.writeTo(body, 'creditCardId');

      await _api.patch('/expenses/$id', data: body);
      return Success(true);
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
        '/expenses/$id/adjustments',
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
        '/expenses/$id/amount',
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
      await _api.post('/expenses/$id/closure', data: {'lastMonth': lastMonth});
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
      await _api.delete('/expenses/$id');
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
