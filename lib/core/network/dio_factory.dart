import 'package:dio/dio.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import '../config/app_config.dart';

/// Constrói a única instância de Dio do app.
///
/// [baseUrl] e [enableLogging] existem para teste — em produção os dois vêm do
/// [AppConfig]. Teste roda em debug, então sem o segundo cada requisição
/// simulada despejaria corpo e cabeçalho na saída do `flutter test`.
Dio buildDio() {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      sendTimeout: AppConfig.sendTimeout,
      contentType: 'application/json',
    ),
  );

  if (AppConfig.logHttp) {
    dio.interceptors.add(
      PrettyDioLogger(
        requestHeader: true,
        requestBody: true,
        responseBody: true,
        responseHeader: false,
        error: true,
        compact: true,
        maxWidth: 100,
      ),
    );
  }

  return dio;
}
