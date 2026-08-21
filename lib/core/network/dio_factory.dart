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
      // Só entra quando existe. Vazio, mandar `x-api-key: ''` faria o backend
      // recusar com 401 em vez de tratar como ausente — e é o mesmo 401, mas
      // por um motivo que não é o real.
      headers: {
        if (AppConfig.apiKey.isNotEmpty) 'x-api-key': AppConfig.apiKey,
      },
    ),
  );

  if (AppConfig.logHttp) {
    dio.interceptors.add(
      PrettyDioLogger(
        // Desligado desde que o header carrega a chave: com ele ligado, cada
        // requisição despejava o segredo no console em debug — e console vira
        // captura de tela, issue e cópia em chat.
        requestHeader: false,
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
