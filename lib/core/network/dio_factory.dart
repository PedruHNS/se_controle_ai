import 'package:dio/dio.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../../data/repositories/auth_repository.dart';
import '../config/app_config.dart';
import 'auth_interceptor.dart';

/// Constrói a única instância de Dio do app.
///
/// [baseUrl] e [enableLogging] existem para teste — em produção os dois vêm do
/// [AppConfig]. Teste roda em debug, então sem o segundo cada requisição
/// simulada despejaria corpo e cabeçalho na saída do `flutter test`.
///
/// [auth] é opcional porque nem todo Dio precisa se identificar: os testes que
/// só verificam serialização montam um sem autenticação nenhuma. Em produção
/// ele sempre vem — sem token, toda rota da API responde 401.
Dio buildDio({AuthRepository? auth}) {
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
      headers: {if (AppConfig.apiKey.isNotEmpty) 'x-api-key': AppConfig.apiKey},
    ),
  );

  // Antes do logger, para o header entrar na requisição antes de ela ser
  // registrada. Com `requestHeader: false` isso não muda o que aparece no
  // console — muda o que aparece se alguém religar aquela opção para depurar.
  if (auth != null) {
    dio.interceptors.add(AuthInterceptor(auth, dio.fetch));
  }

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
