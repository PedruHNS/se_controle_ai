import 'package:flutter_test/flutter_test.dart';
import 'package:se_controle_ai/core/router/app_routes.dart';
import 'package:se_controle_ai/core/router/auth_gate.dart';

/// A decisão do `redirect`, combinação por combinação.
///
/// Sem widget, sem injetor e sem o router global: as quatro entradas viram
/// quatro argumentos, e o que falha diz exatamente qual caso quebrou. O caminho
/// pelo router está coberto em `auth_redirect_test.dart`, que prova que a
/// decisão chega às telas.
void main() {
  group('sessão ainda não resolvida', () {
    test('qualquer tela vira a espera', () {
      expect(
        rotaParaEstado(
          sessaoResolvida: false,
          logado: false,
          indoPara: AppRoutes.homePath,
        ),
        startsWith(AppRoutes.splashPath),
      );
    });

    // O `logado` é irrelevante aqui, e é o ponto: enquanto o SDK não responde,
    // `currentUser` é nulo até em quem está logado. Confiar nele neste instante
    // é o bug que a espera existe para não cometer.
    test('não decide nada com base no logado', () {
      final comSessao = rotaParaEstado(
        sessaoResolvida: false,
        logado: true,
        indoPara: AppRoutes.homePath,
      );
      final semSessao = rotaParaEstado(
        sessaoResolvida: false,
        logado: false,
        indoPara: AppRoutes.homePath,
      );

      expect(comSessao, semSessao);
    });

    test('já na espera, fica quieto', () {
      expect(
        rotaParaEstado(
          sessaoResolvida: false,
          logado: false,
          indoPara: AppRoutes.splashPath,
        ),
        isNull,
      );
    });

    test('guarda o destino na query, para não perdê-lo', () {
      final rota = rotaParaEstado(
        sessaoResolvida: false,
        logado: true,
        indoPara: '/expenses/123',
      );

      expect(
        rota,
        '${AppRoutes.splashPath}?${AppRoutes.deParam}=${Uri.encodeComponent('/expenses/123')}',
      );
    });

    // Guardar o login como destino daria uma volta inútil: resolvida a sessão,
    // quem está logado seria mandado para a tela de login para de lá ser
    // mandado para a home.
    test('o login não vale guardar', () {
      expect(
        rotaParaEstado(
          sessaoResolvida: false,
          logado: false,
          indoPara: AppRoutes.loginPath,
        ),
        AppRoutes.splashPath,
      );
    });
  });

  group('sessão resolvida, sem ninguém logado', () {
    test('qualquer tela vira o login', () {
      expect(
        rotaParaEstado(
          sessaoResolvida: true,
          logado: false,
          indoPara: AppRoutes.expensesPath,
        ),
        AppRoutes.loginPath,
      );
    });

    test('já no login, fica quieto', () {
      expect(
        rotaParaEstado(
          sessaoResolvida: true,
          logado: false,
          indoPara: AppRoutes.loginPath,
        ),
        isNull,
      );
    });

    // Ninguém fica preso na espera: ela não tem botão nem saída própria.
    test('a espera termina no login', () {
      expect(
        rotaParaEstado(
          sessaoResolvida: true,
          logado: false,
          indoPara: AppRoutes.splashPath,
        ),
        AppRoutes.loginPath,
      );
    });
  });

  group('sessão resolvida, com alguém logado', () {
    test('a tela pedida abre', () {
      expect(
        rotaParaEstado(
          sessaoResolvida: true,
          logado: true,
          indoPara: AppRoutes.expensesPath,
        ),
        isNull,
      );
    });

    test('o login vira home', () {
      expect(
        rotaParaEstado(
          sessaoResolvida: true,
          logado: true,
          indoPara: AppRoutes.loginPath,
        ),
        AppRoutes.homePath,
      );
    });

    test('a espera devolve o destino guardado', () {
      expect(
        rotaParaEstado(
          sessaoResolvida: true,
          logado: true,
          indoPara: AppRoutes.splashPath,
          guardado: '/expenses/123',
        ),
        '/expenses/123',
      );
    });

    test('sem destino guardado, a espera termina na home', () {
      expect(
        rotaParaEstado(
          sessaoResolvida: true,
          logado: true,
          indoPara: AppRoutes.splashPath,
        ),
        AppRoutes.homePath,
      );
    });

    // Devolver um dos dois daria ciclo: a espera manda para o login, e o login
    // manda de volta para a espera enquanto a query sobreviver.
    for (final destino in const [AppRoutes.loginPath, AppRoutes.splashPath]) {
      test('destino guardado inválido ($destino) cai na home', () {
        expect(
          rotaParaEstado(
            sessaoResolvida: true,
            logado: true,
            indoPara: AppRoutes.splashPath,
            guardado: destino,
          ),
          AppRoutes.homePath,
        );
      });
    }
  });
}
