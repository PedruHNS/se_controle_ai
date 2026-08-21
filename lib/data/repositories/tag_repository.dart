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
abstract interface class TagRepository {
  /// Já vem ordenado por nome, como o backend devolve.
  Future<Result<List<TagModel>, Failure>> list();

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

  /// Recusa com 409 se algum gasto ou ganho usar a tag (TAG-08) — o backend
  /// devolve quantos na mensagem, e é ela que a tela mostra.
  Future<Result<bool, Failure>> delete(String id);
}

class HttpTagRepository implements TagRepository {
  const HttpTagRepository(this._api);

  final ApiClient _api;

  @override
  Future<Result<List<TagModel>, Failure>> list() async {
    try {
      final response = await _api.get('/tags');
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
  Future<Result<bool, Failure>> delete(String id) async {
    try {
      await _api.delete('/tags/$id');
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
