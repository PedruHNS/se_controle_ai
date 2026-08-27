import 'package:multiple_result/multiple_result.dart';

import '../../core/errors/app_exception.dart';
import '../../core/errors/failure.dart';
import '../../core/network/api_client.dart';
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
  Future<Result<List<TagModel>, Failure>> list();

  Future<Result<TagModel, Failure>> create({
    required String name,
    String? color,
  });

  /// Substitui a tag: nome e cor vão **sempre os dois**, e ela passa a ser o
  /// que foi mandado. `color` nulo é "sem cor", não "não mexe" — por isso não
  /// há [Patch] aqui, ao contrário do cartão e do gasto (CAR-08).
  ///
  /// Quem quer só renomear manda a cor atual de volta. O diálogo de tag tem os
  /// dois campos na tela, então isso não custa nenhuma leitura extra.
  Future<Result<TagModel, Failure>> update(
    String id, {
    required String name,
    String? color,
  });

  Future<Result<TagDeleteOutcome, Failure>> delete(String id);
}

class HttpTagRepository implements TagRepository {
  const HttpTagRepository(this._api);

  final ApiClient _api;

  @override
  Future<Result<List<TagModel>, Failure>> list() async {
    try {
      final response = await _api.get(
        '/tags',

        // O backend lê a query como string, e o zod converte.
      );
      return Success(Decode.listOf(response.data, TagModel.fromJson));
    } on AppException catch (exception) {
      return Error(Failure.fromException(exception));
    } catch (error, stackTrace) {
      return Error(_serializationFailure(error, stackTrace));
    }
  }

  @override
  Future<Result<TagModel, Failure>> create({
    required String name,
    String? color,
  }) async {
    try {
      final response = await _api.post(
        '/tags',
        data: {'name': name, 'color': ?color},
      );
      // O `201` traz a tag pronta. O `restored` também vem no corpo e é
      // ignorado aqui: nenhuma tela distingue "criada" de "restaurada" ainda, e
      // o que ela precisaria dizer não muda o que a lista mostra.
      return Success(TagModel.fromJson(Decode.object(response.data)));
    } on AppException catch (exception) {
      return Error(Failure.fromException(exception));
    } catch (error, stackTrace) {
      return Error(_serializationFailure(error, stackTrace));
    }
  }

  @override
  Future<Result<TagModel, Failure>> update(
    String id, {
    required String name,
    String? color,
  }) async {
    try {
      final response = await _api.post(
        '/tags/$id',
        data: {'name': name, 'color': color},
      );
      // O `200` traz a tag pronta, com o `usageCount` de verdade — é ela que
      // substitui a linha da lista, sem um novo `GET`.
      return Success(TagModel.fromJson(Decode.object(response.data)));
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

  Failure _serializationFailure(Object error, StackTrace stackTrace) =>
      Failure.fromException(
        SerializationException(
          message: '$error',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
}
