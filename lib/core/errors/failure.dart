import 'app_exception.dart';

/// O que a UI **recebe**, dentro do `Error` de um `Result`.
///
/// Contraparte de [AppException]: a exception é técnica e é lançada; o failure
/// carrega mensagem pronta para o usuário e é retornado como valor.
///
/// É `sealed` de propósito — o `switch` na tela fica exaustivo, então um caso
/// novo aqui quebra a compilação em vez de cair num `default` genérico.
sealed class Failure {
  final String message;
  final String? code;
  final AppException? exception;

  const Failure({required this.message, this.code, this.exception});

  /// Faz sentido oferecer "tentar de novo"?
  bool get isRetryable => switch (this) {
    NetworkFailure() || ServerFailure() => true,
    _ => false,
  };

  /// Tradução única de exceção técnica para erro de usuário. Todo caminho de
  /// erro do app passa por aqui, então a mensagem de cada situação vive em um
  /// lugar só.
  static Failure fromException(AppException exception) => switch (exception) {
    NetworkException() => NetworkFailure(
      code: exception.code,
      exception: exception,
    ),
    RequestTimeoutException() => NetworkFailure(
      message: 'O servidor demorou demais para responder.',
      code: exception.code,
      exception: exception,
    ),
    BadCertificateException() => NetworkFailure(
      message:
          'Não foi possível estabelecer uma conexão segura. verifique o certificado SSL/TLS',
      exception: exception,
    ),
    RequestCancelledException() => CancelledFailure(exception: exception),
    BadRequestException() => ValidationFailure(
      message: exception.message,
      code: exception.code,
      issues: exception.issues,
      exception: exception,
    ),
    UnauthorizedException() => UnauthorizedFailure(
      // A mensagem do backend é "Chave de API ausente ou inválida", que descreve
      // o problema para quem opera, não para quem usa. Aqui vale a do app.
      code: exception.code,
      exception: exception,
    ),
    NotFoundException() => NotFoundFailure(
      message: exception.message,
      code: exception.code,
      exception: exception,
    ),
    ConflictException() => ConflictFailure(
      message: exception.message,
      code: exception.code,
      exception: exception,
    ),
    UnprocessableEntityException() => DomainRuleFailure(
      message: exception.message,
      code: exception.code,
      exception: exception,
    ),
    ServerException() => ServerFailure(
      code: exception.code,
      exception: exception,
    ),
    SerializationException() => SerializationFailure(
      message: 'O app não entendeu a resposta do servidor.',
      exception: exception,
    ),
    AuthProviderException() => AuthFailure(
      // A mensagem já vem pronta de quem traduziu o erro do provedor: os
      // códigos do Firebase descrevem o SDK, não o que a pessoa deve fazer.
      message: exception.message,
      code: exception.code,
      exception: exception,
    ),
    UnexpectedResponseException() => UnexpectedFailure(
      code: exception.code,
      exception: exception,
    ),
  };

  @override
  String toString() => '$runtimeType(code: $code, message: $message)';
}

/// Não chegou ao servidor, ou ele não respondeu em tempo. Vale "tentar de novo".
final class NetworkFailure extends Failure {
  const NetworkFailure({
    super.message = 'Sem conexão com o servidor. Verifique sua internet.',
    super.code,
    super.exception,
  });
}

/// 400 — dados recusados. [issues] alimenta o erro embaixo de cada campo.
final class ValidationFailure extends Failure {
  final List<FieldIssue> issues;
  const ValidationFailure({
    required super.message,
    super.code,
    super.exception,
    this.issues = const [],
  });

  /// Mensagem de um campo, para plugar direto no `errorText` do input.
  String? messageFor(String path) {
    for (final issue in issues) {
      if (issue.path == path) return issue.message;
    }
    return null;
  }
}

/// 401 — o app não se identificou para a API.
///
/// **Não é retentável**, e é a diferença que importa: repetir a mesma
/// requisição com a mesma chave dá o mesmo 401 para sempre. O botão "tentar de
/// novo" aqui seria uma promessa falsa.
final class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure({
    super.message =
        'O app não conseguiu se identificar para o servidor. '
        'A chave de acesso está ausente ou incorreta.',
    super.code,
    super.exception,
  });
}

/// 404 — não existe, ou foi apagado em outra tela.
final class NotFoundFailure extends Failure {
  const NotFoundFailure({
    super.message = 'Registro não encontrado.',
    super.code,
    super.exception,
  });
}

/// 409 — conflita com o estado atual (vigências sobrepostas).
final class ConflictFailure extends Failure {
  const ConflictFailure({required super.message, super.code, super.exception});
}

/// 422 — viola uma regra de negócio. A mensagem do backend já é específica e
/// pode ir direto para a tela.
final class DomainRuleFailure extends Failure {
  const DomainRuleFailure({
    required super.message,
    super.code,
    super.exception,
  });
}

/// 5xx — o problema é do servidor, não do que o app enviou.
final class ServerFailure extends Failure {
  const ServerFailure({
    super.message = 'O servidor falhou ao processar. Tente novamente.',
    super.code,
    super.exception,
  });
}

/// O contrato do backend mudou ou o model está desatualizado.
final class SerializationFailure extends Failure {
  const SerializationFailure({required super.message, super.exception});
}

/// A requisição foi cancelada pelo próprio app. Normalmente a UI ignora — é o
/// que acontece ao sair da tela antes da resposta chegar.
final class CancelledFailure extends Failure {
  const CancelledFailure({
    super.message = 'Requisição cancelada.',
    super.exception,
  });
}

/// O login não aconteceu: o provedor recusou, ou o e-mail já entra por outro
/// caminho (AUT-12).
///
/// Não é retentável no sentido de repetir a mesma requisição — o que resolve é
/// entrar de novo, e às vezes por outro provedor. A diferença não muda a tela:
/// nos dois casos o botão à mão é o de login.
final class AuthFailure extends Failure {
  const AuthFailure({required super.message, super.code, super.exception});
}

/// Não caiu em nenhum caso acima.
final class UnexpectedFailure extends Failure {
  const UnexpectedFailure({
    super.message = 'Algo inesperado aconteceu. Tente novamente.',
    super.code,
    super.exception,
  });
}
