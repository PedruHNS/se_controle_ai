import 'package:firebase_auth/firebase_auth.dart';

/// Quem está logado, do lado do provedor.
///
/// Existe para o `firebase_auth` não vazar para controller e tela — o `User` do
/// SDK tem dezenas de campos e métodos que o app não usa, e cada tela que o
/// importasse viraria mais uma amarra ao Firebase. É a mesma aposta que o
/// backend faz na AUT-03 com a coluna `firebase_uid`: identidade é externa, mas
/// o resto do sistema não precisa saber de quem.
class AuthUserModel {
  const AuthUserModel({
    required this.uid,
    this.email,
    this.displayName,
    this.photoUrl,
  });

  /// O `sub` do token, estável para sempre dentro do projeto.
  ///
  /// **Não é o id do backend.** Aquele é o UUID que o `GET /me` devolve, e é
  /// quem é dono das linhas do banco. Os dois convivem de propósito: um
  /// identifica a pessoa no provedor, o outro identifica a pessoa aqui.
  final String uid;

  /// Nulos de verdade, não por precaução: o GitHub entrega
  /// `@users.noreply.github.com` ou nada quando a pessoa mantém o e-mail
  /// privado. É o mesmo motivo de as colunas serem anuláveis no backend, e é o
  /// argumento que fez a AUT-11 ser aprovação por linha em vez de allowlist.
  final String? email;
  final String? displayName;
  final String? photoUrl;

  factory AuthUserModel.fromFirebase(User user) => AuthUserModel(
    uid: user.uid,
    email: user.email,
    displayName: user.displayName,
    photoUrl: user.photoURL,
  );

  /// O que mostrar quando não há nome: o e-mail, e em último caso nada.
  ///
  /// Sem isto, a tela precisaria repetir esse encadeamento em todo lugar que
  /// exibe quem entrou — e um provedor que não manda nem nome nem e-mail é
  /// caso real, não hipótese.
  String get label => displayName ?? email ?? 'Sua conta';

  @override
  String toString() => 'AuthUserModel($uid, $email)';
}
