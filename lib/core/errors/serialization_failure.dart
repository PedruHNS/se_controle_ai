import 'app_exception.dart';
import 'failure.dart';

/// O `Failure` do `catch` largo dos repositórios: payload que não casa com o
/// model, campo que mudou de tipo, lista onde se esperava objeto.
///
/// Existia como `_serializationFailure` privado em **seis** repositórios, com o
/// mesmo corpo em todos. Aqui é uma função só, e o método do repositório volta
/// a caber na tela.
///
/// Não confundir com o `on AppException` que vem antes dele: aquele é erro que
/// a infraestrutura já classificou — rede, 4xx, 5xx. Este é o que sobra, e por
/// definição é o app tendo entendido errado o que o backend mandou.
Failure serializationFailure(Object error, StackTrace stackTrace) =>
    Failure.fromException(
      SerializationException(
        message: '$error',
        cause: error,
        stackTrace: stackTrace,
      ),
    );
