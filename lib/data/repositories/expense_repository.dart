import 'package:multiple_result/multiple_result.dart';

import '../../core/errors/app_exception.dart';
import '../../core/errors/failure.dart';
import '../../core/errors/serialization_failure.dart';
import '../../core/network/api_client.dart';
import '../../core/shared/patch.dart';
import '../models/expense_model.dart';
import 'package:se_controle_ai/data/enums/payment_method.dart';
import 'package:se_controle_ai/data/enums/expense_type.dart';

/// As operações de `/expenses` que a Fase 4 usa.
///
/// **Reajuste, correção e encerramento existem aqui pelo mesmo motivo que em
/// ganhos**: no backend são rotas com semânticas opostas — [adjust] preserva os
/// meses anteriores, [correct] reescreve a vigência atual inteira — e uma
/// assinatura única com um `bool` esconderia justamente a decisão que o usuário
/// precisa tomar (CONC-11).
///
/// **Cada tipo de gasto tem as suas operações de dinheiro, e elas não se
/// misturam** (GPR-17): fixo reajusta, corrige e encerra; parcelado reparcela e
/// quita. O backend recusa a troca com 422, e aqui elas são métodos separados
/// pelo mesmo motivo — uma assinatura só esconderia que são coisas diferentes.
abstract interface class ExpenseRepository {
  /// Sem [month], devolve **todos** os gastos, e cada um vem com
  /// `amountCents: null` — o valor sai do `history`. Com [month], só os
  /// cobrados naquela competência, já com o valor de lá (GFX-10).
  ///
  /// [activeFrom] é o outro recorte, e não se confunde com [month] (GFX-11):
  /// tira o que **acabou antes** daquela competência, sem esconder o que ainda
  /// vai começar nem trocar a semântica do valor. É o que a lista de gastos usa
  /// — a fatura de um cartão continua usando [month], porque ali a pergunta é
  /// "o que vem nesta fatura".
  Future<Result<List<ExpenseModel>, Failure>> list({
    String? month,
    String? activeFrom,
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
  /// Cria um gasto **parcelado**. [totalCents] é o total da compra, não o da
  /// parcela (GPR-02), e o rateio é do backend: a sobra vai para as primeiras,
  /// um centavo em cada (GPR-03).
  ///
  /// Mínimo de 2 parcelas — para 1x existe o gasto fixo não recorrente (GPR-01).
  Future<Result<String, Failure>> createInstallment({
    required String description,
    required PaymentMethod paymentMethod,
    required int totalCents,
    required int installmentsCount,
    required String firstMonth,
    required String tagId,
    String? notes,
    String? creditCardId,
    String? spentAt,
  });

  /// Refaz o plano de [fromMonth] em diante; as parcelas anteriores ficam
  /// intactas, porque já foram cobradas.
  ///
  /// Os dois números são **totais**, não o que falta: [newTotalCents] é o novo
  /// total da compra e [newInstallmentsCount] a nova quantidade contando as já
  /// cobradas (GPR-07/GPR-08). A numeração continua de onde parou, e o "de N"
  /// das antigas é atualizado junto (GPR-10/GPR-11).
  Future<Result<bool, Failure>> reschedule(
    String id, {
    required int newTotalCents,
    required int newInstallmentsCount,
    required String fromMonth,
  });

  /// Quitação: apaga as parcelas de [fromMonth] em diante e ajusta o "de N" das
  /// que ficam (GPR-14). É o "paguei o resto adiantado" — o valor pago na
  /// antecipação não é registrado em lugar nenhum.
  Future<Result<bool, Failure>> settle(String id, {required String fromMonth});

  Future<Result<String, Failure>> createFixed({
    required String description,
    required PaymentMethod paymentMethod,
    required int amountCents,
    required String startMonth,
    required String tagId,
    String? notes,
    String? creditCardId,
    bool recurring = true,

    /// Dia da compra, `YYYY-MM-DD` (GFX-12). Nulo **não vai no corpo**: o
    /// backend distingue ausente de informado, e ausente é o que faz ele usar
    /// o instante do cadastro.
    String? spentAt,
  });

  /// Dados cadastrais — descrição, tag, observação, forma de pagamento, cartão.
  /// **Não são versionados** (GFX-06): mudá-los muda a exibição de todos os
  /// meses, inclusive os passados, e isso é intencional.
  ///
  /// Os campos anuláveis pedem [Patch] pelo mesmo motivo do CAR-08 do cartão:
  /// campo ausente não muda nada, `null` limpa, e um `String?` não diz as duas
  /// coisas. [tagId] fica de fora disso porque a tag é obrigatória (TAG-06):
  /// não existe "limpar a tag", só trocar — então `null` aqui é "não mexi". Trocar para débito limpa o cartão sozinho no backend
  /// (GFX-07), então nesse caso não é preciso mandar `creditCardId: null`.
  ///
  /// Corpo vazio volta 400, então quem chama confere antes se há o que mandar.
  Future<Result<bool, Failure>> updateDetails(
    String id, {
    String? description,
    PaymentMethod? paymentMethod,
    String? tagId,
    Patch<String> notes,
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
    String? activeFrom,
    ExpenseType? type,
    PaymentMethod? paymentMethod,
    String? creditCardId,
  }) async {
    try {
      final response = await _api.get(
        '/expenses',
        queryParameters: {
          'month': month,
          'activeFrom': activeFrom,
          'type': type?.wire,
          'paymentMethod': paymentMethod?.wire,
          'creditCardId': creditCardId,
        },
      );
      return Success(Decode.listOf(response.data, ExpenseModel.fromJson));
    } on AppException catch (exception) {
      return Error(Failure.fromException(exception));
    } catch (error, stackTrace) {
      return Error(serializationFailure(error, stackTrace));
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
      return Error(serializationFailure(error, stackTrace));
    }
  }

  @override
  Future<Result<String, Failure>> createFixed({
    required String description,
    required PaymentMethod paymentMethod,
    required int amountCents,
    required String startMonth,
    required String tagId,
    String? notes,
    String? creditCardId,
    bool recurring = true,
    String? spentAt,
  }) async {
    try {
      final response = await _api.post(
        '/expenses',
        data: {
          'type': ExpenseType.fixed.wire,
          'description': description,
          'tagId': tagId,
          'notes': notes,
          'paymentMethod': paymentMethod.wire,
          'creditCardId': creditCardId,
          'amountCents': amountCents,
          'startMonth': startMonth,
          'recurring': recurring,
          // Chave omitida quando nulo, e não mandada como null: ausente é o
          // que faz o backend usar o instante do cadastro (GFX-12).
          'spentAt': ?spentAt,
        },
      );
      return Success(Decode.object(response.data)['id'] as String);
    } on AppException catch (exception) {
      return Error(Failure.fromException(exception));
    } catch (error, stackTrace) {
      return Error(serializationFailure(error, stackTrace));
    }
  }

  @override
  Future<Result<bool, Failure>> updateDetails(
    String id, {
    String? description,
    PaymentMethod? paymentMethod,
    String? tagId,
    Patch<String> notes = const Patch.keep(),
    Patch<String> creditCardId = const Patch.keep(),
  }) async {
    try {
      // O `?` só escreve a chave quando o valor não é null — para estes dois,
      // null é "não mexi". Os dois anuláveis vão pelo Patch, logo abaixo, porque
      // neles null é um valor que precisa chegar ao backend.
      final body = <String, dynamic>{
        'description': ?description,
        'paymentMethod': ?paymentMethod?.wire,
        'tagId': ?tagId,
      };

      notes.writeTo(body, 'notes');
      creditCardId.writeTo(body, 'creditCardId');

      await _api.patch('/expenses/$id', data: body);
      return Success(true);
    } on AppException catch (exception) {
      return Error(Failure.fromException(exception));
    } catch (error, stackTrace) {
      return Error(serializationFailure(error, stackTrace));
    }
  }

  @override
  Future<Result<String, Failure>> createInstallment({
    required String description,
    required PaymentMethod paymentMethod,
    required int totalCents,
    required int installmentsCount,
    required String firstMonth,
    required String tagId,
    String? notes,
    String? creditCardId,
    String? spentAt,
  }) async {
    try {
      final response = await _api.post(
        '/expenses',
        data: {
          'type': ExpenseType.installment.wire,
          'description': description,
          'tagId': tagId,
          'notes': notes,
          'paymentMethod': paymentMethod.wire,
          'creditCardId': creditCardId,
          'totalCents': totalCents,
          'installmentsCount': installmentsCount,
          'firstMonth': firstMonth,
          // Chave omitida quando nulo, e não mandada como null: ausente é o
          // que faz o backend usar o instante do cadastro (GFX-12).
          'spentAt': ?spentAt,
        },
      );
      return Success(Decode.object(response.data)['id'] as String);
    } on AppException catch (exception) {
      return Error(Failure.fromException(exception));
    } catch (error, stackTrace) {
      return Error(serializationFailure(error, stackTrace));
    }
  }

  @override
  Future<Result<bool, Failure>> reschedule(
    String id, {
    required int newTotalCents,
    required int newInstallmentsCount,
    required String fromMonth,
  }) async {
    try {
      await _api.post(
        '/expenses/$id/reschedule',
        data: {
          'newTotalCents': newTotalCents,
          'newInstallmentsCount': newInstallmentsCount,
          'fromMonth': fromMonth,
        },
      );
      return Success(true);
    } on AppException catch (exception) {
      return Error(Failure.fromException(exception));
    } catch (error, stackTrace) {
      return Error(serializationFailure(error, stackTrace));
    }
  }

  @override
  Future<Result<bool, Failure>> settle(
    String id, {
    required String fromMonth,
  }) async {
    try {
      await _api.post(
        '/expenses/$id/settlement',
        data: {'fromMonth': fromMonth},
      );
      return Success(true);
    } on AppException catch (exception) {
      return Error(Failure.fromException(exception));
    } catch (error, stackTrace) {
      return Error(serializationFailure(error, stackTrace));
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
      return Error(serializationFailure(error, stackTrace));
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
      return Error(serializationFailure(error, stackTrace));
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
      return Error(serializationFailure(error, stackTrace));
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
      return Error(serializationFailure(error, stackTrace));
    }
  }
}
