import 'package:dio/dio.dart';

import '../../data/repositories/auth_repository.dart';

/// Põe o ID token em toda requisição, e renova uma vez quando o servidor
/// recusa (AUT-01, AUT-06).
///
/// Fica no transporte, e não em cada repositório, pelo mesmo motivo da limpeza
/// de query nula do [ApiClient]: a exigência é do backend inteiro, então
/// repositório novo e método novo já nascem cobertos.
///
/// **Não é `QueuedInterceptor`.** Enfileirar parece a escolha óbvia — evitaria
/// duas renovações simultâneas —, mas reexecutar a requisição de dentro do
/// `onError` de um interceptor enfileirado trava: a fila está ocupada
/// justamente por quem está esperando. E a renovação simultânea não é problema
/// aqui: o `firebase_auth` mantém um refresh só em voo e entrega o mesmo
/// resultado a todos os chamadores.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._auth, this._retry);

  final AuthRepository _auth;

  /// Reexecuta uma requisição já corrigida — na prática, o `fetch` do próprio
  /// Dio. Entra como dependência para o teste conseguir observar a repetição
  /// sem subir servidor.
  final Future<Response<dynamic>> Function(RequestOptions) _retry;

  /// Marca a requisição que já foi renovada uma vez.
  ///
  /// Sem isto, um token que o servidor recusa sempre — conta desabilitada,
  /// projeto errado — viraria laço infinito de renovar e repetir.
  static const _jaRenovou = 'auth-ja-renovou';

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // A requisição que está sendo repetida já carrega o token recém-renovado.
    // Sem esta saída, `dio.fetch` passa por aqui de novo e sobrescreve o token
    // novo pelo velho — a repetição levaria exatamente a credencial que o
    // servidor acabou de recusar, e o 401 se repetiria sem explicação.
    if (options.extra[_jaRenovou] == true) return handler.next(options);

    final token = await _auth.idToken();

    // Sem token a requisição segue mesmo assim, e leva 401. É de propósito:
    // barrar aqui devolveria um erro inventado pelo app, que se pareceria com
    // falha de rede. O 401 do servidor é a verdade, e já tem tratamento.
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;

    // 403 não passa por aqui de propósito: cadastro pendente (AUT-11) não se
    // resolve com token novo. Renovar ali seria gastar uma ida à rede para
    // receber o mesmo 403.
    if (err.response?.statusCode != 401 || options.extra[_jaRenovou] == true) {
      return handler.next(err);
    }

    // O SDK renova sozinho quando falta menos de cinco minutos para expirar.
    // Chegar num 401 significa que o servidor discorda de um token que o SDK
    // ainda considerava bom — relógio fora de hora, ou sessão revogada. Forçar
    // é a única tentativa que faz sentido.
    final token = await _auth.idToken(forceRefresh: true);

    if (token == null) return handler.next(err);

    options.extra[_jaRenovou] = true;
    options.headers['Authorization'] = 'Bearer $token';

    try {
      handler.resolve(await _retry(options));
    } on DioException catch (erro) {
      handler.next(erro);
    }
  }
}
