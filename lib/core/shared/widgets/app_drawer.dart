import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router/app_routes.dart';

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
            icon: Icons.trending_up,
            label: 'Ganhos',
            route: AppRoutes.incomes,
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
