import 'package:dio/dio.dart';

import '../errors/app_exception.dart';

/// Único lugar do app que conhece `DioException`.
///
/// Classifica a falha técnica em uma [AppException]. Quem traduz para mensagem
/// de usuário é `Failure.fromException` — aqui só se decide *o que* aconteceu.
AppException mapDioException(DioException exception) {
  final stackTrace = exception.stackTrace;

  // Método + URL completa em toda falha de rede. É a informação que falta quando
  // o app "não conecta": sem ela não se distingue baseUrl errada de servidor
  // fora do ar. O `FailureCardWidget` mostra isto em debug.
  final target =
      '${exception.requestOptions.method} ${exception.requestOptions.uri}';

  return switch (exception.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.transformTimeout => RequestTimeoutException(
      message: 'Timeout em $target',
      cause: exception,
      stackTrace: stackTrace,
    ),
    DioExceptionType.connectionError ||
    DioExceptionType.unknown => NetworkException(
      message:
          'Não alcançou $target — ${exception.message ?? 'conexão falhou'}',
      cause: exception,
      stackTrace: stackTrace,
    ),
    DioExceptionType.badCertificate => BadCertificateException(
      message: 'Certificado inválido em $target',
      cause: exception,
      stackTrace: stackTrace,
    ),
    DioExceptionType.cancel => RequestCancelledException(
      cause: exception,
      stackTrace: stackTrace,
    ),
    DioExceptionType.badResponse => _fromResponse(exception),
  };
}

/// O backend responde erro sempre com `{code, message, issues?}`.
AppException _fromResponse(DioException exception) {
  final DioException(:response, :requestOptions, :stackTrace) = exception;

  final status = response?.statusCode ?? 0;
  final envelope = response?.data is Map<String, dynamic>
      ? response!.data as Map<String, dynamic>
      : null;
  final code = envelope?['code'] as String?;
  // Fallback existe porque um proxy ou 502 de gateway devolve HTML, não o
  // envelope — nesse caso não há `message` para ler.
  final message =
      envelope?['message'] as String? ??
      'HTTP $status sem o envelope esperado em '
          '${requestOptions.method} ${requestOptions.uri}';

  return switch (status) {
    400 => BadRequestException(
      message: message,
      code: code,
      issues: _issuesOf(envelope?['issues']),
      cause: exception,
      stackTrace: stackTrace,
    ),
    401 => UnauthorizedException(
      message: message,
      code: code,
      cause: exception,
      stackTrace: stackTrace,
    ),
    404 => NotFoundException(
      message: message,
      code: code,
      cause: exception,
      stackTrace: stackTrace,
    ),
    409 => ConflictException(
      message: message,
      code: code,
      cause: exception,
      stackTrace: stackTrace,
    ),
    422 => UnprocessableEntityException(
      message: message,
      code: code,
      cause: exception,
      stackTrace: stackTrace,
    ),
    >= 500 => ServerException(
      message: message,
      code: code,
      statusCode: status,
      cause: exception,
      stackTrace: stackTrace,
    ),
    _ => UnexpectedResponseException(
      message: message,
      code: code,
      statusCode: status,
      cause: exception,
      stackTrace: stackTrace,
    ),
  };
}

List<FieldIssue> _issuesOf(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map<String, dynamic>>()
      .map(
        (issue) => FieldIssue(
          path: issue['path'] as String? ?? '',
          message: issue['message'] as String? ?? 'Valor inválido',
        ),
      )
      .toList(growable: false);
}
