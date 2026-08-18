import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/view/home_page.dart';
import 'app_routes.dart';

/// Configuração de navegação do app.
///
/// Instância única e `final` de propósito: recriar o GoRouter a cada build do
/// widget raiz descarta a pilha de navegação e o app "volta" para a home sozinho
/// a cada rebuild.
final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.homePath,

  /// Loga cada navegação no console em debug. Vale muito quando um redirect
  /// leva para lugar inesperado.
  debugLogDiagnostics: kDebugMode,

  routes: [
    GoRoute(
      path: AppRoutes.homePath,
      name: AppRoutes.home,
      builder: (context, state) => const HomePage(),

      // Telas filhas entram como `routes:` daqui quando cada fase chegar. Rota
      // aninhada mantém o "voltar" coerente: de /expenses/:id o pop volta para
      // /expenses, não para a home.
      //
      // routes: [
      //   GoRoute(
      //     path: AppRoutes.expenseDetailPath,   // ':id', relativo — sem '/'
      //     name: AppRoutes.expenseDetail,
      //     builder: (context, state) => ExpenseDetailPage(
      //       id: state.pathParameters[RouteParams.id]!,
      //     ),
      //   ),
      // ],
    ),
  ],

  /// Cai aqui em URL que não existe — digitada, deep link antigo, typo em
  /// `goNamed`. Sem isto o go_router mostra uma tela de erro crua.
  errorBuilder: (context, state) =>
      _RouteErrorPage(location: state.uri.toString(), error: state.error),

  /// Ponto de entrada para regra de acesso, quando houver login. Hoje o backend
  /// não tem autenticação (veja ROADMAP.md), então nada é redirecionado.
  ///
  /// redirect: (context, state) {
  ///   if (!isSignedIn && state.matchedLocation != '/login') return '/login';
  ///   return null;
  /// },
);

class _RouteErrorPage extends StatelessWidget {
  const _RouteErrorPage({required this.location, this.error});

  final String location;
  final Exception? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Tela não encontrada')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.wrong_location_outlined,
                size: 56,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                'Nenhuma tela responde por este endereço.',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                location,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
                textAlign: TextAlign.center,
              ),
              // O detalhe técnico só em debug: em release não diz nada ao usuário.
              if (kDebugMode && error != null) ...[
                const SizedBox(height: 8),
                Text(
                  '$error',
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.goNamed(AppRoutes.home),
                icon: const Icon(Icons.home_outlined),
                label: const Text('Ir para o início'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
