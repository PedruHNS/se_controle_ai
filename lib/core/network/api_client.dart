import 'package:dio/dio.dart';

import '../errors/app_exception.dart';
import 'exception_mapper.dart';

/// Fachada sobre o Dio. Devolve o JSON cru (`Map`, `List` ou `null` no 204) e
/// **lança** [AppException] quando algo dá errado.
///
/// Sem `Result` aqui de propósito: quem transforma erro em valor é o
/// repositório, que é também quem sabe decodificar o JSON no model. Esta classe
/// tem uma responsabilidade só — falar HTTP.
///
/// O que ela garante: `DioException` **nunca** sai daqui. Quem chama lida com
/// [AppException], então o repositório não precisa conhecer o Dio.
///
/// ```dart
/// // no repositório:
/// final json = await _api.get('/summary', query: {'month': month});
/// return MonthlySummary.fromJson(json as Map<String, dynamic>);
/// ```
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
      queryParameters: queryParameters,
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
      queryParameters: queryParameters,
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
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    ),
  );

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
