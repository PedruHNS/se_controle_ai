import 'package:multiple_result/multiple_result.dart';

import '../../core/errors/app_exception.dart';
import '../../core/errors/failure.dart';
import '../../core/network/api_client.dart';
import '../../core/shared/patch.dart';
import '../models/tag_model.dart';

/// As quatro operações de `/tags`.
///
/// Como o cartão, a tag não tem vigência nem histórico: renomear muda o rótulo
/// em todo o passado, e isso é intencional (TAG-03). Por isso aqui não existe o
/// par reajuste/correção que os ganhos têm.
/// O que a exclusão fez: `true` quando a tag foi arquivada por estar em uso,
/// `false` quando foi apagada de verdade. A tela diz coisas diferentes para
/// cada caso, e sem isto teria que adivinhar comparando listas.
typedef TagDeleteOutcome = ({bool archived});

abstract interface class TagRepository {
  /// Já vem ordenado por nome, como o backend devolve.
  ///
  /// Sem [includeArchived], só as ativas — é o que o seletor de lançamento
  /// precisa, já que arquivada não pode ser escolhida (TAG-08). A tela de tags
  /// pede as duas.
  Future<Result<List<TagModel>, Failure>> list({bool includeArchived});

  /// Devolve o `id` gerado, que é tudo que o `201` traz.
  ///
  /// Nome repetido ignorando maiúscula volta 409 (TAG-01), que vira
  /// [ConflictFailure] — é o caso de quem digita "moradia" já tendo "Moradia".
  Future<Result<String, Failure>> create({required String name, String? color});

  /// Edição parcial com a semântica do CAR-08: campo ausente não muda nada,
  /// `null` limpa a cor. O nome não é anulável, por isso vai como `String?`.
  Future<Result<bool, Failure>> update(
    String id, {
    String? name,
    Patch<String> color,
  });

  /// Dois desfechos (TAG-08): tag sem uso é apagada, tag em uso é **arquivada**
  /// — continua nos lançamentos que já a usam e some das escolhas de
  /// lançamento novo. O retorno diz qual dos dois aconteceu.
  Future<Result<TagDeleteOutcome, Failure>> delete(String id);

  /// Traz de volta uma arquivada. 409 se ela já estiver ativa.
  Future<Result<bool, Failure>> restore(String id);
}

class HttpTagRepository implements TagRepository {
  const HttpTagRepository(this._api);

  final ApiClient _api;

  @override
  Future<Result<List<TagModel>, Failure>> list({
    bool includeArchived = false,
  }) async {
    try {
      final response = await _api.get(
        '/tags',
        // O backend lê a query como string, e o zod converte.
        queryParameters: {'includeArchived': includeArchived ? 'true' : null},
      );
      return Success(Decode.listOf(response.data, TagModel.fromJson));
    } on AppException catch (exception) {
      return Error(Failure.fromException(exception));
    } catch (error, stackTrace) {
      return Error(_serializationFailure(error, stackTrace));
    }
  }

  @override
  Future<Result<String, Failure>> create({
    required String name,
    String? color,
  }) async {
    try {
      final response = await _api.post(
        '/tags',
        data: {'name': name, 'color': ?color},
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
    Patch<String> color = const Patch.keep(),
  }) async {
    try {
      final body = <String, dynamic>{'name': ?name};
      color.writeTo(body, 'color');

      await _api.patch('/tags/$id', data: body);
      return Success(true);
    } on AppException catch (exception) {
      return Error(Failure.fromException(exception));
    } catch (error, stackTrace) {
      return Error(_serializationFailure(error, stackTrace));
    }
  }

  @override
  Future<Result<TagDeleteOutcome, Failure>> delete(String id) async {
    try {
      final response = await _api.delete('/tags/$id');
      final archived = Decode.object(response.data)['archived'] as bool;
      return Success((archived: archived));
    } on AppException catch (exception) {
      return Error(Failure.fromException(exception));
    } catch (error, stackTrace) {
      return Error(_serializationFailure(error, stackTrace));
    }
  }

  @override
  Future<Result<bool, Failure>> restore(String id) async {
    try {
      await _api.post('/tags/$id/restore');
      return Success(true);
    } on AppException catch (exception) {
      return Error(Failure.fromException(exception));
    } catch (error, stackTrace) {
      return Error(_serializationFailure(error, stackTrace));
    }
  }

  Failure _serializationFailure(Object error, StackTrace stackTrace) =>
      Failure.fromException(
        SerializationException(
          message: '$error',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
}
