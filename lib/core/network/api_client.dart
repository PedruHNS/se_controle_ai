import 'package:dio/dio.dart';

import '../errors/app_exception.dart';
import 'exception_mapper.dart';

/// Fachada sobre o Dio. Devolve o `Response` da requisição — o corpo já
/// desserializado fica em `response.data`, como `Map`, `List` ou `null` no 204 —
/// e **lança** [AppException] quando algo dá errado.
///
/// Sem `Result` aqui de propósito: quem transforma erro em valor é o
/// repositório, que é também quem sabe decodificar o JSON no model. Esta classe
/// tem uma responsabilidade só — falar HTTP.
///
/// O que ela garante: `DioException` **nunca** sai daqui. Quem chama lida com
/// [AppException], e nunca com o erro do Dio.
///
/// ```dart
/// // no repositório:
/// final response = await _api.get('/summary', queryParameters: {'month': month});
/// return MonthlySummaryModel.fromJson(Decode.object(response.data));
/// ```
///
/// **O `.data` não é opcional.** O retorno é `dynamic`, então esquecê-lo passa
/// pelo `flutter analyze` e só aparece como `TypeError` em runtime. É o que
/// aconteceu uma vez — ver o grupo `devolve o Response do Dio` em
/// `test/core/network/api_client_test.dart`, que é o teste que guarda isso.
class ApiClient {
  ApiClient(this._dio);

  final Dio _dio;

  /// Exposto para configuração posterior (ex.: interceptor de autenticação).
  Dio get dio => _dio;

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    Options? options,
  }) => _request<Response>(
    () => _dio.get(
      path,
      queryParameters: _query(queryParameters),
      options: options,
      cancelToken: cancelToken,
    ),
  );

  Future<dynamic> post(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    Options? options,
  }) => _request<Response>(
    () => _dio.post(
      path,
      data: data,
      queryParameters: _query(queryParameters),
      options: options,
      cancelToken: cancelToken,
    ),
  );

  /// `PATCH` é a operação de **correção** do backend — reescreve o valor desde o
  /// início, ao contrário do `POST` de reajuste, que preserva os meses
  /// anteriores. Ver `/incomes/:id/amount` e `/expenses/:id/amount`.
  Future<dynamic> patch(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    Options? options,
  }) => _request<Response>(
    () => _dio.patch(
      path,
      data: data,
      queryParameters: _query(queryParameters),
      options: options,
      cancelToken: cancelToken,
    ),
  );

  Future<dynamic> delete(
    String path, {
    CancelToken? cancelToken,
    Object? data,
    Options? options,
    Map<String, dynamic>? queryParameters,
  }) => _request<Response?>(
    () => _dio.delete(
      path,
      data: data,
      queryParameters: _query(queryParameters),
      options: options,
      cancelToken: cancelToken,
    ),
  );

  /// A query sem as chaves nulas.
  ///
  /// **O dio não remove parâmetro nulo** — ele serializa `{'month': null}` como
  /// `?month`, chave pelada. O Express entrega isso ao zod como string vazia, e
  /// os schemas do backend são `optional()`: aceitam a **ausência** do campo e
  /// recusam o vazio. Resultado sem esta limpeza: `GET /incomes` sem mês volta
  /// 400 em vez de listar tudo.
  ///
  /// Fica aqui, e não em cada repositório, porque a armadilha é do transporte —
  /// todo método novo e todo repositório novo já nasce protegido. Devolver
  /// `null` quando não sobra nada evita a `?` sozinha no fim da URL.
  static Map<String, dynamic>? _query(Map<String, dynamic>? parameters) {
    if (parameters == null) return null;

    final clean = <String, dynamic>{
      for (final entry in parameters.entries)
        if (entry.value != null) entry.key: entry.value,
    };

    return clean.isEmpty ? null : clean;
  }

  /// Executa uma chamada HTTP e impede que o Dio vaze para as camadas acima.
  Future<T> _request<T>(Future<T> Function() call) async {
    try {
      final request = call();

      return await request;
    } on DioException catch (exception) {
      throw mapDioException(exception);
    }
  }
}

/// Ajudantes de decodificação, para o repositório não repetir cast.
///
/// Recebem o **corpo** (`response.data`), não o `Response`.
abstract final class Decode {
  static Map<String, dynamic> object(dynamic json) =>
      json as Map<String, dynamic>;

  /// Lista de objetos, cada um passado por [fromJson].
  static List<T> listOf<T>(
    dynamic json,
    T Function(Map<String, dynamic>) fromJson,
  ) => (json as List<dynamic>)
      .cast<Map<String, dynamic>>()
      .map(fromJson)
      .toList(growable: false);
}
