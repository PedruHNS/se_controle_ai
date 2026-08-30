import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:signals/signals_flutter.dart';

import '../../../core/errors/failure.dart';
import '../controller/login_controller.dart';

/// A porta de entrada do app.
///
/// Não guarda senha e não tem cadastro: a identidade vem de fora (AUT-01), e
/// aqui só se escolhe por onde entrar. Por isso não há campo nenhum nesta tela
/// — nem e-mail, nem "esqueci minha senha", nem link para criar conta.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  /// `factory` no get_it, então quem libera é este `State` — o container não
  /// guarda a instância. Mesma divisão dos formulários do app.pod
  final _controller = GetIt.I<LoginController>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'Se Controle AI',
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Entre para ver seus gastos e ganhos.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                SignalBuilder(
                  builder: (context) {
                    final user = _controller.user.value;

                    return user == null
                        ? _EntrarComGoogle(controller: _controller)
                        : _JaEntrou(controller: _controller);
                  },
                ),

                SignalBuilder(
                  builder: (context) {
                    final failure = _controller.failure.value;

                    return failure == null
                        ? const SizedBox.shrink()
                        : _Aviso(failure: failure);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EntrarComGoogle extends StatelessWidget {
  const _EntrarComGoogle({required this.controller});

  final LoginController controller;

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context) {
        final working = controller.working.value;

        return FilledButton.icon(
          key: const Key('login-google'),
          // Nulo desabilita o botão. Dois toques abririam duas folhas de escolha
          // de conta, e a segunda cancela a primeira — o sintoma é "cliquei e
          // não aconteceu nada".
          onPressed: working ? null : controller.signInWithGoogle,
          icon: working
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.login),
          label: Text(working ? 'Entrando…' : 'Entrar com Google'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        );
      },
    );
  }
}

/// O que a tela mostra depois de entrar, **enquanto não há redirecionamento**.
///
/// É provisório de propósito: quando o `redirect` do router entrar, ninguém
/// mais vai ver esta parte, porque logar tira a pessoa daqui. Até lá é o que
/// permite conferir o login de ponta a ponta sem navegação nenhuma.
class _JaEntrou extends StatelessWidget {
  const _JaEntrou({required this.controller});

  final LoginController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SignalBuilder(
      builder: (context) {
        final user = controller.user.value;
        final working = controller.working.value;

        return Column(
          children: [
            Icon(
              Icons.check_circle_outline,
              color: theme.colorScheme.primary,
              size: 32,
            ),
            const SizedBox(height: 12),
            Text(
              'Entrou como',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            Text(
              user?.label ?? '',
              key: const Key('login-quem-entrou'),
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              key: const Key('login-sair'),
              onPressed: working ? null : controller.signOut,
              icon: const Icon(Icons.logout),
              label: const Text('Sair'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.failure});

  final Failure failure;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 20, color: theme.colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              failure.message,
              key: const Key('login-erro'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
