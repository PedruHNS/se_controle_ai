/// O que a camada de infraestrutura **lança**.
///
/// Diferença de propósito em relação a [Failure](failure.dart):
///
/// - `AppException` é técnica. Carrega status HTTP, tipo de erro do Dio, corpo
///   cru, causa e stack trace — o que serve para depurar e logar.
/// - `Failure` é o que sobe para a UI, com mensagem pronta para o usuário.
///
/// O `ApiClient` converte uma na outra, então exceção nunca vaza do repositório.
/// Fontes que não são HTTP (storage local, parse de arquivo) também lançam daqui.
sealed class AppException implements Exception {
  final String message;
  final String? code;
  final int? statusCode;
  final Object? cause;
  final StackTrace? stackTrace;

  const AppException({
    required this.message,
    this.code,
    this.statusCode,
    this.cause,
    this.stackTrace,
  });

  @override
  String toString() =>
      '$runtimeType(status: $statusCode, code: $code, message: $message)';
}

/// Não chegou ao servidor: sem rede, DNS falhou, conexão recusada.
final class NetworkException extends AppException {
  const NetworkException({
    super.message = 'Falha de conexão com o servidor',
    super.code,
    super.cause,
    super.stackTrace,
  });
}

/// O servidor não respondeu no prazo.
final class RequestTimeoutException extends AppException {
  const RequestTimeoutException({
    super.message = 'Tempo de resposta esgotado',
    super.code,
    super.cause,
    super.stackTrace,
  });
}

/// Certificado TLS rejeitado.
final class BadCertificateException extends AppException {
  const BadCertificateException({
    super.message = 'Certificado do servidor inválido',
    super.cause,
    super.stackTrace,
  });
}

/// A requisição foi cancelada pelo app (troca de tela, novo filtro).
final class RequestCancelledException extends AppException {
  const RequestCancelledException({
    super.message = 'Requisição cancelada',
    super.cause,
    super.stackTrace,
  });
}

/// 400 — o zod do backend recusou o corpo. `issues` vem campo a campo.
final class BadRequestException extends AppException {
  final List<FieldIssue> issues;

  const BadRequestException({
    required super.message,
    super.code,
    super.statusCode = 400,
    super.cause,
    super.stackTrace,
    this.issues = const [],
  });
}

/// Um problema em um campo específico do corpo enviado.
class FieldIssue {
  /// Caminho do campo como o backend devolve: `amountCents`, `startMonth`.
  final String path;
  final String message;

  const FieldIssue({required this.path, required this.message});

  @override
  String toString() => '$path: $message';
}

/// 404 — o recurso não existe.
final class NotFoundException extends AppException {
  const NotFoundException({
    required super.message,
    super.code,
    super.statusCode = 404,
    super.cause,
    super.stackTrace,
  });
}

/// 409 — conflito de estado. No backend hoje: vigências sobrepostas.
final class ConflictException extends AppException {
  const ConflictException({
    required super.message,
    super.code,
    super.statusCode = 409,
    super.cause,
    super.stackTrace,
  });
}

/// 422 — dados válidos, mas a operação viola uma regra de negócio.
final class UnprocessableEntityException extends AppException {
  const UnprocessableEntityException({
    required super.message,
    super.code,
    super.statusCode = 422,
    super.cause,
    super.stackTrace,
  });
}

/// 5xx — falha do servidor.
final class ServerException extends AppException {
  const ServerException({
    required super.message,
    super.code,
    super.statusCode,
    super.cause,
    super.stackTrace,
  });
}

/// O JSON chegou mas não bate com o model. Bug de contrato, não do usuário.
final class SerializationException extends AppException {
  const SerializationException({
    required super.message,
    super.cause,
    super.stackTrace,
  });
}

/// 401 — o servidor não aceitou quem o app diz ser.
///
/// Uma causa só desde 31/08: o ID token está ausente, expirado ou inválido
/// (AUT-06). Eram duas — a `x-api-key` do binário errada era a outra —, e a
/// chave saiu quando ficou claro que ela não acrescentava nada ao token. O
/// backend sempre devolveu a mesma frase para os dois casos de propósito: a
/// distinção só interessaria a quem está tentando adivinhar.
///
/// O interceptor tenta renovar o token uma vez antes de deixar isto subir. Se
/// chegou aqui, renovar não resolveu.
final class UnauthorizedException extends AppException {
  const UnauthorizedException({
    required super.message,
    super.code,
    super.cause,
    super.stackTrace,
  });
}

// Não há 403 aqui, e a ausência é a regra: o backend não produz nenhum. Houve
// um entre 26 e 27/08, para o cadastro que ainda não tinha sido liberado
// (AUT-11) — a regra saiu, e com ela a exceção e a tela de espera que a
// acompanhava. Se um 403 chegar hoje, veio de proxy ou WAF e cai em
// [UnexpectedResponseException], que é onde deve cair.

/// O provedor de identidade recusou ou falhou — o Google, ou o Firebase Auth.
///
/// Não é o 401 de [UnauthorizedException], e a distância entre os dois é grande:
/// lá o app tinha credencial e ela não serviu; aqui nem chegamos a ter token
/// para mandar. Os desfechos também são opostos — um pede recompilar com a
/// chave certa, o outro pede entrar de novo.
final class AuthProviderException extends AppException {
  const AuthProviderException({
    required super.message,
    super.code,
    super.cause,
    super.stackTrace,
  });
}

/// Status ou situação que não se encaixa em nenhum caso acima.
final class UnexpectedResponseException extends AppException {
  const UnexpectedResponseException({
    required super.message,
    super.code,
    super.statusCode,
    super.cause,
    super.stackTrace,
  });
}
