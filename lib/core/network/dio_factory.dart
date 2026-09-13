import 'package:dio/dio.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../../data/repositories/auth_repository.dart';
import '../config/app_config.dart';
import 'auth_interceptor.dart';

/// Constrói a única instância de Dio do app.
///
/// **O endereço vem do [AppConfig], nunca escrito aqui.** Esteve chumbado em
/// `https://secontroleai.com.br` até 13/09/2026, com a linha do [AppConfig]
/// comentada para um teste em aparelho — e enquanto esteve assim os
/// `env/*.json` ficaram anulados em silêncio: o `--dart-define-from-file`
/// continuava sendo lido e ignorado, então `flutter run` na máquina de casa
/// falava com a VPS de produção sem ninguém perceber. Trocar de ambiente é
/// trocar de arquivo:
///
/// ```
/// flutter run --dart-define-from-file=env/dev.json    # API no container local
/// flutter run --dart-define-from-file=env/prod.json   # VPS
/// ```
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
    ),
  );

  // Nenhum header fixo aqui desde 31/08. Havia um `x-api-key` vindo do
  // `--dart-define`, e ele saiu junto com a tranca do backend: uma chave só
  // para todos os aparelhos, que não expira e fica legível dentro do APK, não
  // acrescentava nada ao token do Firebase que o interceptor manda abaixo.
  //
  // O interceptor vem antes do logger para o `Authorization` entrar na
  // requisição antes de ela ser registrada. Com `requestHeader: false` isso não
  // muda o que aparece no console — muda o que apareceria se alguém religasse
  // aquela opção para depurar, e agora o que vazaria ali é o token.
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
