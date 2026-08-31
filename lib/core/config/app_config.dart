import 'package:flutter/foundation.dart';

/// Configuração de ambiente do app.
abstract final class AppConfig {
  /// Endereço do backend, gravado no binário em tempo de build.
  ///
  /// A forma normal de passar é por arquivo, um por ambiente:
  ///
  /// ```
  /// flutter run       --dart-define-from-file=env/dev.json
  /// flutter build apk --dart-define-from-file=env/prod.json --release
  /// ```
  ///
  /// `env/dev.json` e `env/prod.json` estão no `.gitignore`, nomeados um a um;
  /// os `env/*.example.json` vão para o repositório e mostram o formato. Por
  /// arquivo e não por `--dart-define` solto porque o comando solto é longo,
  /// some no histórico do shell e é fácil de rodar pela metade — já saiu APK
  /// apontando para a rede local sem ninguém perceber, e só apareceu abrindo o
  /// binário com `strings`.
  ///
  /// `--dart-define` continua funcionando e tem precedência sobre o arquivo,
  /// o que serve para sobrescrever um valor pontual sem editar nada.
  static const _envBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// Usado quando não se passa `--dart-define`, para `flutter run` e
  /// `flutter build apk` funcionarem sem flag.
  ///
  /// É o IP da máquina de desenvolvimento na rede local, e não `10.0.2.2`, que
  /// era o valor anterior: aquele apelido **só existe no emulador**, então em
  /// aparelho físico a conexão morria e a tela mostrava "Sem conexão" com a
  /// Wi-Fi funcionando. O IP da rede é alcançável dos dois — aparelho e
  /// emulador.
  ///
  /// **É DHCP.** Se o roteador trocar o IP da máquina, atualize aqui e em
  /// `android/app/src/main/res/xml/network_security_config.xml`, que precisa
  /// autorizar HTTP para o mesmo host. Ou passe `--dart-define` e ignore este
  /// valor.
  static const _defaultBaseUrl = 'http://192.168.0.14:3333';

  /// Com aparelho ligado no USB, isto também funciona depois de
  /// `adb reverse tcp:3333 tcp:3333` — e não depende de Wi-Fi nem de DHCP:
  ///
  /// ```
  /// flutter run --dart-define=API_BASE_URL=http://localhost:3333
  /// ```
  static String get apiBaseUrl =>
      _envBaseUrl.isNotEmpty ? _envBaseUrl : _defaultBaseUrl;

  // Não há mais `apiKey` aqui. Ela existiu até 31/08, vinda do `--dart-define`
  // e mandada no header `x-api-key`, e saiu com a tranca do backend: nunca foi
  // segredo depois do build — `strings -a app-release.apk` a encontrava — e o
  // que identifica o app hoje é o ID token do Firebase, que é por pessoa e
  // expira sozinho.

  static const connectTimeout = Duration(seconds: 30);
  static const receiveTimeout = Duration(seconds: 30);
  static const sendTimeout = Duration(seconds: 15);

  /// Loga request/response no console. Desligado em release.
  static bool get logHttp => kDebugMode;
}
