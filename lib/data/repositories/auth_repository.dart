import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:multiple_result/multiple_result.dart';

import '../../core/errors/app_exception.dart';
import '../../core/errors/failure.dart';
import '../models/auth_user_model.dart';

/// O pedaço do `google_sign_in` que este repositório usa.
///
/// Port estreito, e aqui não é preferência de estilo: o `GoogleSignIn` da v7 é
/// um singleton de construtor privado (`GoogleSignIn._()`), então não há como
/// forjá-lo no teste. Sem esta porta, "a pessoa desistiu no meio" e "o client
/// está mal configurado" seriam caminhos que só se conhece em produção — e o
/// segundo é justamente o que quebra no APK de release.
abstract interface class GoogleIdentity {
  /// Abre a escolha de conta e devolve o ID token do Google.
  ///
  /// `null` quando a pessoa desistiu. Fechar a folha não é erro: tratar como
  /// erro encheria a tela de aviso vermelho para quem só mudou de ideia.
  ///
  /// Lança [AuthProviderException] quando o provedor falha de verdade.
  Future<String?> signIn();

  /// Esquece a conta escolhida.
  ///
  /// Sem isto, sair e entrar de novo pula a escolha e volta na mesma conta —
  /// o que se lê como "o app não me deixa trocar de usuário".
  Future<void> signOut();
}

/// A implementação de verdade, sobre o singleton do pacote.
class PlatformGoogleIdentity implements GoogleIdentity {
  bool _iniciado = false;

  /// A v7 exige `initialize()` antes de qualquer coisa, e ele é assíncrono.
  ///
  /// Sob demanda em vez de no `main`: só quem vai logar paga, e o start do app
  /// não ganha mais um `await`.
  ///
  /// Sem `serverClientId` de propósito — no Android o plugin lê o client web do
  /// `google-services.json` (o `oauth_client` de `client_type: 3`), que o
  /// plugin do Gradle transforma no recurso `default_web_client_id`. Passar o
  /// valor à mão aqui seria duplicar uma configuração que já existe e pode
  /// divergir dela.
  Future<void> _iniciar() async {
    if (_iniciado) return;

    await GoogleSignIn.instance.initialize();
    _iniciado = true;
  }

  @override
  Future<String?> signIn() async {
    await _iniciar();

    try {
      final conta = await GoogleSignIn.instance.authenticate();

      return conta.authentication.idToken;
    } on GoogleSignInException catch (error, stack) {
      // Desistir e ser interrompido dão no mesmo para quem está olhando: a tela
      // volta ao que era, sem aviso nenhum.
      if (error.code == GoogleSignInExceptionCode.canceled ||
          error.code == GoogleSignInExceptionCode.interrupted) {
        return null;
      }

      throw AuthProviderException(
        message: 'Não foi possível entrar com o Google.',
        code: error.code.name,
        cause: error,
        stackTrace: stack,
      );
    }
  }

  @override
  Future<void> signOut() => GoogleSignIn.instance.signOut();
}

/// Entrar, sair e provar quem é (AUT-01).
///
/// Não fala com a nossa API: o backend não tem register, login, refresh nem
/// logout — tudo isso acontece contra o Firebase, e o que sobe para a API é só
/// o token. Quem confirma a sessão do lado de lá é o `GET /me`.
abstract interface class AuthRepository {
  /// Quem está logado agora, sem esperar nada. `null` se ninguém.
  AuthUserModel? get current;

  /// Emite a cada login e logout, e uma vez no começo com o estado atual.
  ///
  /// É o que o `redirect` do router escuta: sem stream, sair em uma tela
  /// deixaria as outras achando que ainda há sessão.
  Stream<AuthUserModel?> get changes;

  Future<Result<AuthUserModel, Failure>> signInWithGoogle();

  Future<Result<bool, Failure>> signOut();

  /// O ID token para o header `Authorization`.
  ///
  /// O `firebase_auth` renova sozinho quando falta menos de cinco minutos para
  /// expirar, então [forceRefresh] só serve depois de um 401 — o caso em que o
  /// servidor discorda de um token que o SDK ainda considera bom.
  ///
  /// O padrão vai na **interface**, e não só na implementação: sem ele, chamar
  /// `idToken()` por este tipo não passa o argumento — e quem observa a chamada
  /// de fora, um duplo de teste, vê uma invocação sem `forceRefresh` em vez de
  /// uma com `false`.
  Future<String?> idToken({bool forceRefresh = false});
}

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth, this._google);

  final FirebaseAuth _auth;
  final GoogleIdentity _google;

  @override
  AuthUserModel? get current {
    final user = _auth.currentUser;

    return user == null ? null : AuthUserModel.fromFirebase(user);
  }

  @override
  Stream<AuthUserModel?> get changes => _auth.authStateChanges().map(
    (user) => user == null ? null : AuthUserModel.fromFirebase(user),
  );

  @override
  Future<Result<AuthUserModel, Failure>> signInWithGoogle() async {
    try {
      final googleToken = await _google.signIn();

      if (googleToken == null) {
        return const Error(CancelledFailure(message: 'Login cancelado.'));
      }

      // Só o `idToken`: o `accessToken` da v7 vem de outro fluxo, o de
      // autorização de escopos, e o Firebase não precisa dele para confirmar
      // quem é a pessoa.
      final credencial = GoogleAuthProvider.credential(idToken: googleToken);
      final resultado = await _auth.signInWithCredential(credencial);
      final user = resultado.user;

      if (user == null) {
        return const Error(
          AuthFailure(message: 'O login não devolveu nenhuma conta.'),
        );
      }

      return Success(AuthUserModel.fromFirebase(user));
    } on AppException catch (exception) {
      return Error(Failure.fromException(exception));
    } on FirebaseAuthException catch (error, stack) {
      return Error(Failure.fromException(_traduzir(error, stack)));
    }
  }

  @override
  Future<Result<bool, Failure>> signOut() async {
    try {
      // Os dois lados. Sair só do Firebase deixa a conta do Google escolhida, e
      // o próximo login entra sozinho na mesma — sem tela, sem escolha, sem
      // explicação.
      await _google.signOut();
      await _auth.signOut();

      return const Success(true);
    } on AppException catch (exception) {
      return Error(Failure.fromException(exception));
    } on FirebaseAuthException catch (error, stack) {
      return Error(Failure.fromException(_traduzir(error, stack)));
    }
  }

  /// `null` quando não há ninguém logado — e também quando a renovação falha.
  ///
  /// O segundo caso é deliberado: quem chama é o interceptor, e a requisição
  /// seguir sem header vira 401, que já tem tratamento. Estourar aqui
  /// transformaria uma oscilação de rede em exceção no meio de qualquer tela.
  @override
  Future<String?> idToken({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      return await user.getIdToken(forceRefresh);
    } catch (_) {
      return null;
    }
  }

  /// De erro do Firebase para exceção nossa.
  ///
  /// Dois casos ganham nome e o resto cai num só, e isso não é preguiça: os
  /// códigos do SDK descrevem o SDK. Mostrar `invalid-credential` na tela não
  /// diz a ninguém o que fazer em seguida.
  AppException _traduzir(FirebaseAuthException error, StackTrace stack) =>
      switch (error.code) {
        // AUT-12. O console tem "One account per email address" ligado por
        // padrão, e é ele que produz isto: o e-mail já entrou por outro
        // provedor. Juntar as duas contas exigiria um fluxo de vinculação que
        // está fora do corte — então o honesto é dizer por onde entrar.
        'account-exists-with-different-credential' => AuthProviderException(
          message:
              'Esta conta já entra por outro provedor. '
              'Use o mesmo que você usou da primeira vez.',
          code: error.code,
          cause: error,
          stackTrace: stack,
        ),

        // Vira NetworkFailure, que é retentável — e é o certo: aqui "tentar de
        // novo" é uma promessa que o app pode cumprir.
        'network-request-failed' => NetworkException(
          code: error.code,
          cause: error,
          stackTrace: stack,
        ),

        _ => AuthProviderException(
          message: 'Não foi possível entrar. Tente de novo.',
          code: error.code,
          cause: error,
          stackTrace: stack,
        ),
      };
}
