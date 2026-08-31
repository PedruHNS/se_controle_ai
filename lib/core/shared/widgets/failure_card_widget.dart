import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../errors/failure.dart';

/// Card reutilizável para apresentar uma falha ao usuário.
///
/// O `switch` no [Failure] é exaustivo, então uma categoria nova de erro força a
/// escolha de ícone e texto aqui em vez de cair num genérico "algo deu errado".
class FailureCardWidget extends StatelessWidget {
  const FailureCardWidget({required this.failure, this.onRetry, super.key});

  final Failure failure;

  /// Quando nulo, o botão não aparece. Só faz sentido em falha que vale repetir
  /// — [Failure.isRetryable] diz quais.
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showRetry = onRetry != null && failure.isRetryable;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icon, size: 56, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              _title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              failure.message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (failure is ValidationFailure) ..._issues(theme),
            // Só em debug: a mensagem de usuário não diz *qual* endereço falhou,
            // e é justamente isso que se precisa saber quando a URL do backend
            // está errada. Em release isto não aparece.
            if (kDebugMode && failure.exception != null) ...[
              const SizedBox(height: 16),
              Text(
                failure.exception!.message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                  fontFamily: 'monospace',
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (showRetry) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => onRetry!(),
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar de novo'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _issues(ThemeData theme) {
    final issues = (failure as ValidationFailure).issues;
    if (issues.isEmpty) return const [];

    return [
      const SizedBox(height: 12),
      for (final issue in issues)
        Text(
          '• ${issue.message}',
          style: theme.textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
    ];
  }

  IconData get _icon => switch (failure) {
    NetworkFailure() => Icons.wifi_off_outlined,
    UnauthorizedFailure() => Icons.key_off_outlined,
    NotFoundFailure() => Icons.search_off_outlined,
    ValidationFailure() => Icons.error_outline,
    ConflictFailure() => Icons.merge_type_outlined,
    DomainRuleFailure() => Icons.rule_outlined,
    ServerFailure() => Icons.cloud_off_outlined,
    SerializationFailure() => Icons.extension_off_outlined,
    CancelledFailure() => Icons.cancel_outlined,
    TooManyRequestsFailure() => Icons.hourglass_top_outlined,
    AuthFailure() => Icons.person_off_outlined,
    UnexpectedFailure() => Icons.help_outline,
  };

  String get _title => switch (failure) {
    NetworkFailure() => 'Sem conexão',
    // "Sessão expirada" e não "acesso negado": desde que a `x-api-key` saiu, o
    // 401 tem uma causa só, e ela tem conserto — entrar de novo. "Negado"
    // sugeria que a pessoa não tem permissão, que é outra coisa.
    UnauthorizedFailure() => 'Sessão expirada',
    NotFoundFailure() => 'Não encontrado',
    ValidationFailure() => 'Dados inválidos',
    ConflictFailure() => 'Conflito',
    DomainRuleFailure() => 'Operação não permitida',
    ServerFailure() => 'Falha no servidor',
    // Nomeado sem jargão: para o usuário o que importa é que precisa atualizar
    // o app, não que o JSON não bateu com o model.
    SerializationFailure() => 'Versão incompatível',
    CancelledFailure() => 'Cancelado',
    // Sem a palavra "erro": nada deu errado, foi rápido demais. E sem "limite",
    // que soa a plano pago — o que houve foi ritmo.
    TooManyRequestsFailure() => 'Muitas tentativas',
    // "Login" e não "autenticação": o que a pessoa faz em seguida é entrar de
    // novo, e às vezes por outro provedor. Difere do UnauthorizedFailure acima,
    // que é a chave de API e não tem ação nenhuma na tela.
    AuthFailure() => 'Falha no login',
    UnexpectedFailure() => 'Erro inesperado',
  };
}
