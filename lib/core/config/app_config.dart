import 'package:flutter/foundation.dart';

/// Configuração de ambiente do app.
abstract final class AppConfig {
  /// Endereço do backend, gravado no binário em tempo de build:
  ///
  /// ```
  /// flutter run   --dart-define=API_BASE_URL=http://192.168.1.9:3333
  /// flutter build apk --dart-define=API_BASE_URL=https://api.exemplo.com
  /// ```
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
  static const _defaultBaseUrl = 'http://192.168.1.9:3333';

  /// Com aparelho ligado no USB, isto também funciona depois de
  /// `adb reverse tcp:3333 tcp:3333` — e não depende de Wi-Fi nem de DHCP:
  ///
  /// ```
  /// flutter run --dart-define=API_BASE_URL=http://localhost:3333
  /// ```
  static String get apiBaseUrl =>
      _envBaseUrl.isNotEmpty ? _envBaseUrl : _defaultBaseUrl;

  /// Chave que a API exige no header `x-api-key`, gravada no binário em tempo
  /// de build:
  ///
  /// ```
  /// flutter run --dart-define=API_KEY=<a chave>
  /// ```
  ///
  /// Vazia por padrão, e é o certo: o backend na sua máquina sobe sem tranca,
  /// e um valor de exemplo aqui só serviria para ser esquecido no lugar do
  /// verdadeiro. Vazia, o header simplesmente não é enviado.
  ///
  /// **Não é login.** Não há usuário nem sessão do outro lado — corrigir uma
  /// chave errada passa por recompilar, não por entrar de novo.
  static const apiKey = String.fromEnvironment('API_KEY');

  static const connectTimeout = Duration(seconds: 30);
  static const receiveTimeout = Duration(seconds: 30);
  static const sendTimeout = Duration(seconds: 15);

  /// Loga request/response no console. Desligado em release.
  static bool get logHttp => kDebugMode;
}
