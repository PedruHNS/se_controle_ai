import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:se_controle_ai/data/services/selected_month_service.dart';
import 'package:se_controle_ai/features/home/controller/home_controller.dart';
import 'package:signals/signals_flutter.dart';

import '../../../data/repositories/auth_repository.dart';
import '../../di/injector.dart';
import '../../router/app_routes.dart';
import '../../theme/theme_controller.dart';

/// Menu lateral do app.
///
/// Mora na home, que é a única tela que não foi empilhada por outra: das demais
/// se sai pelo "voltar", e um menu repetido lá só daria caminhos de ida para
/// onde já se está.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
            ),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                'Se Controle',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
          _DrawerItem(
            icon: Icons.dashboard_outlined,
            label: 'Dashboard',
            route: AppRoutes.dashboard,
          ),
          _DrawerItem(
            icon: Icons.trending_up,
            label: 'Ganhos',
            route: AppRoutes.incomes,
          ),
          _DrawerItem(
            icon: Icons.payments_outlined,
            label: 'Gastos',
            route: AppRoutes.expenses,
          ),
          _DrawerItem(
            icon: Icons.credit_card,
            label: 'Cartões',
            route: AppRoutes.creditCards,
          ),
          _DrawerItem(
            icon: Icons.sell_outlined,
            label: 'Tags',
            route: AppRoutes.tags,
          ),

          // O seletor fica no fim, depois de um divisor: é ajuste do app, não
          // um lugar para onde ir — e misturá-lo com os destinos faria a lista
          // de navegação ter um item que não navega.
          const Divider(height: 32),
          const _ThemeSelector(),
          const SizedBox(height: 8),

          // Sair também não é destino, e fica por último de propósito: é a
          // ação mais fácil de tocar sem querer e a mais chata de desfazer —
          // entrar de novo custa a folha do Google inteira.
          const Divider(height: 8),
          const _Sair(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Escolha de tema, aqui mesmo no menu — sem tela de ajustes, que teria um
/// item só.
///
/// **Três opções, e "Sistema" é o padrão.** Só claro e escuro tiraria o
/// comportamento que já existia, que é acompanhar o aparelho; quem tem o
/// sistema em automático por horário perderia isso ao encostar no seletor.
///
/// A escolha vale para esta sessão — ver [ThemeController].
class _ThemeSelector extends StatelessWidget {
  const _ThemeSelector();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = getIt<ThemeController>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tema', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          SignalBuilder(
            builder: (context) => SegmentedButton<ThemeMode>(
              // Sem rótulo escrito: três palavras não cabem na largura do menu
              // sem quebrar, e o ícone de cada uma é conhecido. O nome fica no
              // tooltip, para quem tiver dúvida — e para o leitor de tela.
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.brightness_auto_outlined),
                  tooltip: 'Sistema',
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode_outlined),
                  tooltip: 'Claro',
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode_outlined),
                  tooltip: 'Escuro',
                ),
              ],
              selected: {controller.mode.value},
              onSelectionChanged: (selection) =>
                  controller.select(selection.first),
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.route,
  });

  final IconData icon;
  final String label;
  final String route;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: () {
        // Fecha o menu **antes** de navegar: o Drawer aberto é uma entrada no
        // histórico local da rota, e deixá-lo aberto faz o primeiro "voltar" da
        // tela nova apenas fechar o menu da tela anterior.
        Navigator.pop(context);

        // `push` e não `go`: o menu sai da home, e o "voltar" da tela nova tem
        // que devolver para ela — é o mesmo caminho que a seção de ganhos da
        // home já usa.
        context.pushNamed(route);
      },
    );
  }
}

/// Encerra a sessão.
///
/// Não navega: quem tira a pessoa daqui é o `redirect` do router, avisado pelo
/// [AuthRefresh]. Mandar um `go` daqui criaria um segundo caminho para a mesma
/// decisão, e os dois precisariam concordar para sempre.
class _Sair extends StatelessWidget {
  const _Sair();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = GetIt.I<AuthRepository>().current;

    return ListTile(
      key: const Key('drawer-sair'),
      leading: Icon(Icons.logout, color: theme.colorScheme.error),
      title: Text('Sair', style: TextStyle(color: theme.colorScheme.error)),
      // Quem está logado, embaixo: sem isso não há nenhum lugar no app que
      // responda "com qual conta eu entrei?".
      subtitle: user == null ? null : Text(user.label),
      onTap: () {
        GetIt.I<AuthRepository>().signOut();
        getIt.resetLazySingleton<HomeController>();
        getIt.resetLazySingleton<SelectedMonthService>();
      },
    );
  }
}
