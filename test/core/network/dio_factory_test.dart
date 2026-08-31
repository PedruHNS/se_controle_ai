import 'package:flutter_test/flutter_test.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:se_controle_ai/core/network/dio_factory.dart';

void main() {
  // O Dio não carrega mais nenhum header fixo: o `x-api-key` saiu em 31/08 com
  // a tranca do backend, e quem se identifica agora é o `AuthInterceptor`, por
  // requisição. Este teste existe para o header não voltar por descuido.
  test('sem interceptor de auth, nenhum header de credencial é montado', () {
    final headers = buildDio().options.headers;

    expect(headers.containsKey('x-api-key'), isFalse);
    expect(headers.containsKey('Authorization'), isFalse);
  });

  // Regressão de verdade: com `requestHeader: true` o logger despejava a
  // credencial no console a cada requisição, e console vira captura de tela e
  // cópia em chat. Valia para a chave; vale mais ainda para o `Authorization`,
  // que hoje leva o ID token. O campo é público no pacote, então dá para
  // afirmar em vez de supor.
  test('o logger não imprime headers, para o token não vazar no console', () {
    final logger = buildDio().interceptors.whereType<PrettyDioLogger>();

    expect(
      logger,
      isNotEmpty,
      reason: 'o teste roda em debug, então ele existe',
    );
    expect(logger.first.requestHeader, isFalse);
  });
}
