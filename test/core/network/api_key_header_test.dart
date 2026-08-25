import 'package:flutter_test/flutter_test.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:se_controle_ai/core/config/app_config.dart';
import 'package:se_controle_ai/core/network/dio_factory.dart';

void main() {
  // A chave vem de `--dart-define`, que é tempo de build: o teste não consegue
  // injetar uma. Então o que dá para verificar aqui é o outro lado da regra —
  // sem chave definida, o header não pode existir. É esse o caso que roda na
  // máquina de quem desenvolve, e um `x-api-key: ''` acidental viraria 401
  // contra um backend que está com a tranca ligada.
  //
  // O caminho com chave está coberto do lado do backend, no apiKeyGuard.spec.
  test('sem API_KEY definida, o header não é enviado', () {
    expect(
      AppConfig.apiKey,
      isEmpty,
      reason: 'o teste roda sem --dart-define; se falhar, o ambiente mudou',
    );

    final dio = buildDio();

    expect(dio.options.headers.containsKey('x-api-key'), isFalse);
  });

  // Regressão de verdade: com `requestHeader: true` o logger despejava a chave
  // no console a cada requisição, e console vira captura de tela e cópia em
  // chat. O campo é público no pacote, então dá para afirmar em vez de supor.
  test('o logger não imprime headers, para a chave não vazar no console', () {
    final logger = buildDio().interceptors.whereType<PrettyDioLogger>();

    expect(
      logger,
      isNotEmpty,
      reason: 'o teste roda em debug, então ele existe',
    );
    expect(logger.first.requestHeader, isFalse);
  });
}
