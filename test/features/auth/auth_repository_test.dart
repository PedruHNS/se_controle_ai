import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:se_controle_ai/core/errors/failure.dart';
import 'package:se_controle_ai/data/models/auth_user_model.dart';
import 'package:se_controle_ai/data/repositories/auth_repository.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockGoogleIdentity extends Mock implements GoogleIdentity {}

class MockUserCredential extends Mock implements UserCredential {}

class MockUser extends Mock implements User {}

class FakeAuthCredential extends Fake implements AuthCredential {}

void main() {
  late MockFirebaseAuth auth;
  late MockGoogleIdentity google;
  late FirebaseAuthRepository repository;

  setUpAll(() => registerFallbackValue(FakeAuthCredential()));

  setUp(() {
    auth = MockFirebaseAuth();
    google = MockGoogleIdentity();
    repository = FirebaseAuthRepository(auth, google);

    when(() => google.signOut()).thenAnswer((_) async {});
    when(() => auth.signOut()).thenAnswer((_) async {});
  });

  /// Um usuário do Firebase já logado, para os casos de sucesso.
  MockUser logado({
    String uid = 'uid-do-pedro',
    String? email = 'pedro@exemplo.com',
    String? nome = 'Pedro',
  }) {
    final user = MockUser();
    when(() => user.uid).thenReturn(uid);
    when(() => user.email).thenReturn(email);
    when(() => user.displayName).thenReturn(nome);
    when(() => user.photoURL).thenReturn(null);
    return user;
  }

  /// O par que o `signInWithCredential` devolve.
  void stubLoginFirebase(MockUser? user) {
    final credential = MockUserCredential();
    when(() => credential.user).thenReturn(user);
    when(
      () => auth.signInWithCredential(any()),
    ).thenAnswer((_) async => credential);
  }

  group('entrar com o Google', () {
    test('devolve quem entrou', () async {
      when(() => google.signIn()).thenAnswer((_) async => 'token-do-google');
      stubLoginFirebase(logado());

      final resultado = await repository.signInWithGoogle();

      expect(resultado.isSuccess(), isTrue);
      final user = resultado.tryGetSuccess() as AuthUserModel;
      expect(user.uid, 'uid-do-pedro');
      expect(user.email, 'pedro@exemplo.com');
      expect(user.displayName, 'Pedro');
    });

    test('desistir no meio não é erro de tela', () async {
      // A pessoa fechou a folha de escolha de conta. O port devolve null, e o
      // repositório precisa distinguir isso de falha — senão a tela mostra
      // aviso vermelho para quem só mudou de ideia.
      when(() => google.signIn()).thenAnswer((_) async => null);

      final resultado = await repository.signInWithGoogle();

      expect(resultado.tryGetError(), isA<CancelledFailure>());
      verifyNever(() => auth.signInWithCredential(any()));
    });

    test('sem rede vira falha retentável, e não erro de login', () async {
      // A diferença importa no botão que a tela oferece: aqui "tentar de novo"
      // é uma promessa que dá para cumprir.
      when(() => google.signIn()).thenAnswer((_) async => 'token-do-google');
      when(
        () => auth.signInWithCredential(any()),
      ).thenThrow(FirebaseAuthException(code: 'network-request-failed'));

      final falha = (await repository.signInWithGoogle()).tryGetError();

      expect(falha, isA<NetworkFailure>());
      expect(falha!.isRetryable, isTrue);
    });

    test('erro desconhecido do provedor não vaza o código do SDK', () async {
      when(() => google.signIn()).thenAnswer((_) async => 'token-do-google');
      when(
        () => auth.signInWithCredential(any()),
      ).thenThrow(FirebaseAuthException(code: 'invalid-credential'));

      final falha = (await repository.signInWithGoogle()).tryGetError();

      expect(falha, isA<AuthFailure>());
      expect(falha!.message, isNot(contains('invalid-credential')));
      // O código continua disponível para log, só não vai para a tela.
      expect(falha.code, 'invalid-credential');
    });

    test('login sem conta de volta não passa por sucesso', () async {
      when(() => google.signIn()).thenAnswer((_) async => 'token-do-google');
      stubLoginFirebase(null);

      expect((await repository.signInWithGoogle()).isError(), isTrue);
    });
  });

  group('sair', () {
    test('desconecta o Google também', () async {
      // Sair só do Firebase deixa a conta escolhida no Google, e o próximo
      // login entra sozinho na mesma — parece que o app não deixa trocar de
      // usuário.
      final resultado = await repository.signOut();

      expect(resultado.isSuccess(), isTrue);
      verify(() => google.signOut()).called(1);
      verify(() => auth.signOut()).called(1);
    });
  });

  group('token', () {
    test('sem ninguém logado, não há token', () async {
      when(() => auth.currentUser).thenReturn(null);

      expect(await repository.idToken(), isNull);
    });

    test('devolve o token de quem está logado', () async {
      final user = logado();
      when(() => user.getIdToken(any())).thenAnswer((_) async => 'id-token');
      when(() => auth.currentUser).thenReturn(user);

      expect(await repository.idToken(), 'id-token');
      verify(() => user.getIdToken(false)).called(1);
    });

    test('forceRefresh chega ao SDK', () async {
      // É o que o interceptor usa depois de um 401: o servidor discorda de um
      // token que o SDK ainda considera válido.
      final user = logado();
      when(() => user.getIdToken(any())).thenAnswer((_) async => 'novo-token');
      when(() => auth.currentUser).thenReturn(user);

      expect(await repository.idToken(forceRefresh: true), 'novo-token');
      verify(() => user.getIdToken(true)).called(1);
    });

    test('renovação que falha devolve null em vez de estourar', () async {
      // Quem chama é o interceptor. Estourar aqui viraria exceção no meio de
      // qualquer tela; sem header, a requisição vira 401, que já tem caminho.
      final user = logado();
      when(
        () => user.getIdToken(any()),
      ).thenThrow(FirebaseAuthException(code: 'network-request-failed'));
      when(() => auth.currentUser).thenReturn(user);

      expect(await repository.idToken(), isNull);
    });
  });

  group('quem está logado', () {
    test('current traduz o usuário do Firebase', () {
      // Construído fora do `when`: o mocktail fica em modo de stub entre o
      // `when(...)` e o `thenReturn(...)`, e chamar `when` de novo lá dentro
      // estoura com "Cannot call `when` within a stub response".
      final user = logado(nome: null);
      when(() => auth.currentUser).thenReturn(user);

      expect(repository.current?.uid, 'uid-do-pedro');
      // Sem nome, o rótulo cai no e-mail — provedor que não manda nome é caso
      // real, não hipótese.
      expect(repository.current?.label, 'pedro@exemplo.com');
    });

    test('changes emite null ao sair', () async {
      final user = logado();
      when(
        () => auth.authStateChanges(),
      ).thenAnswer((_) => Stream<User?>.fromIterable([user, null]));

      expect(await repository.changes.map((u) => u?.uid).toList(), [
        'uid-do-pedro',
        null,
      ]);
    });
  });
}
