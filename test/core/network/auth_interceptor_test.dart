import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:se_controle_ai/core/network/auth_interceptor.dart';

import '../../fixtures/mocks.dart';

/// Um servidor de mentira que responde o que a lista mandar, em ordem.
///
/// Adapter e não mock do `Dio`: assim a requisição percorre a cadeia de
/// interceptors de verdade, que é justamente o que está sob teste — repetir
/// depois de um 401 passa por ela de novo.
class _AdapterFalso implements HttpClientAdapter {
  _AdapterFalso(this.respostas);

  /// Códigos a devolver, um por requisição. O último se repete se acabarem.
  final List<int> respostas;

  /// Cópia dos headers de cada requisição, e não o `RequestOptions`.
  ///
  /// A repetição reaproveita o **mesmo objeto**, mutando os headers. Guardando
  /// a referência, a primeira requisição pareceria ter levado o token da
  /// segunda — e o teste do caminho sem sessão passaria a mentir.
  final List<Map<String, dynamic>> recebidas = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    recebidas.add(Map<String, dynamic>.from(options.headers));

    final status = recebidas.length <= respostas.length
        ? respostas[recebidas.length - 1]
        : respostas.last;

    return ResponseBody.fromString(
      status == 200
          ? '{"ok":true}'
          : '{"code":"UNAUTHORIZED","message":"Token ausente, inválido ou expirado"}',
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late MockAuthRepository auth;

  ({Dio dio, _AdapterFalso servidor}) montar(List<int> respostas) {
    final dio = Dio(BaseOptions(baseUrl: 'http://teste'));
    final servidor = _AdapterFalso(respostas);

    dio.httpClientAdapter = servidor;
    dio.interceptors.add(AuthInterceptor(auth, dio.fetch));

    return (dio: dio, servidor: servidor);
  }

  /// [renovado] tem padrão literal, e não `?? normal`: o teste que precisa da
  /// renovação **falhando** passa `null`, e um `??` transformaria isso de volta
  /// no token velho — o caso deixaria de ser testado sem ninguém perceber.
  void stubToken({
    String? normal = 'token-velho',
    String? renovado = 'token-velho',
  }) {
    when(
      () => auth.idToken(forceRefresh: false),
    ).thenAnswer((_) async => normal);
    when(
      () => auth.idToken(forceRefresh: true),
    ).thenAnswer((_) async => renovado);
  }

  setUp(() => auth = authRepositoryMock());

  group('toda requisição leva o token', () {
    test('põe o Bearer quando há sessão', () async {
      stubToken();
      final (:dio, :servidor) = montar([200]);

      await dio.get<dynamic>('/tags');

      expect(servidor.recebidas.single['Authorization'], 'Bearer token-velho');
    });

    test('sem sessão, segue sem header em vez de barrar', () async {
      // Barrar aqui devolveria um erro inventado pelo app, parecido com falha
      // de rede. O 401 do servidor é a verdade, e já tem tratamento.
      stubToken(normal: null);
      final (:dio, :servidor) = montar([401]);

      await expectLater(
        dio.get<dynamic>('/tags'),
        throwsA(isA<DioException>()),
      );

      expect(servidor.recebidas.first.containsKey('Authorization'), isFalse);
    });
  });

  group('401', () {
    test('renova à força e repete uma vez', () async {
      // O SDK renova sozinho perto de expirar. Um 401 significa que o servidor
      // discorda de um token que o SDK ainda achava bom — relógio fora de hora,
      // ou sessão revogada.
      stubToken(normal: 'token-velho', renovado: 'token-novo');
      final (:dio, :servidor) = montar([401, 200]);

      final resposta = await dio.get<dynamic>('/tags');

      expect(resposta.statusCode, 200);
      expect(servidor.recebidas, hasLength(2));
      expect(servidor.recebidas.last['Authorization'], 'Bearer token-novo');
      verify(() => auth.idToken(forceRefresh: true)).called(1);
    });

    test('não repete duas vezes', () async {
      // Token que o servidor recusa sempre — conta desabilitada, projeto errado
      // — viraria laço infinito de renovar e repetir sem a marca na requisição.
      stubToken(normal: 'token-velho', renovado: 'token-novo');
      final (:dio, :servidor) = montar([401]);

      await expectLater(
        dio.get<dynamic>('/tags'),
        throwsA(isA<DioException>()),
      );

      expect(servidor.recebidas, hasLength(2));
      verify(() => auth.idToken(forceRefresh: true)).called(1);
    });

    test('sem token novo, o 401 sobe como veio', () async {
      stubToken(normal: 'token-velho', renovado: null);
      final (:dio, :servidor) = montar([401]);

      await expectLater(
        dio.get<dynamic>('/tags'),
        throwsA(isA<DioException>()),
      );

      expect(servidor.recebidas, hasLength(1));
    });
  });

  test('403 não tenta renovar', () async {
    // Cadastro pendente (AUT-11) não se resolve com token novo. Renovar ali
    // seria gastar uma ida à rede para receber o mesmo 403.
    stubToken();
    final (:dio, :servidor) = montar([403]);

    await expectLater(dio.get<dynamic>('/tags'), throwsA(isA<DioException>()));

    expect(servidor.recebidas, hasLength(1));
    verifyNever(() => auth.idToken(forceRefresh: true));
  });
}
