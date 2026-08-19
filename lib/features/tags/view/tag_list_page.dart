import 'package:flutter/material.dart';

/// Tags — tela ainda vazia, de propósito.
///
/// O backend não tem endpoint de tags (veja ROADMAP.md), então não há repositório
/// nem controller para chamar. A tela existe para o item do menu ter para onde ir
/// e para o aviso ficar na cara de quem abrir: está em desenvolvimento, não é uma
/// lista vazia por falta de cadastro.
class TagListPage extends StatelessWidget {
  const TagListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Tags'), centerTitle: true),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.construction_outlined,
                size: 56,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                'Em desenvolvimento',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'As tags ainda não existem no servidor. Esta tela entra quando o '
                'endpoint chegar.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
