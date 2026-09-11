import 'package:flutter/material.dart';
import 'package:se_controle_ai/core/theme/app_theme.dart';
import 'package:se_controle_ai/data/models/tag_model.dart';
import 'package:se_controle_ai/core/utils/tag_color.dart';

class TagTile extends StatelessWidget {
  final TagModel tag;
  final void Function(TagModel tag)? onEdit;
  final void Function(TagModel tag)? onDelete;

  const TagTile({super.key, required this.tag, this.onEdit, this.onDelete});

  const TagTile.esqueleto({super.key})
    : tag = const TagModel(
        id: '',
        name: 'Categoria',
        color: '#78909C',
        usageCount: 12,
      ),
      onEdit = null,
      onDelete = null;

  String _countUser(int count) {
    return switch (tag.usageCount) {
      0 => 'Sem uso',
      1 => '1 lançamento',
      final n => '$n lançamentos',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: .all(12),
      decoration: BoxDecoration(
        color: theme.appColors.card,
        borderRadius: .circular(10),
        boxShadow: [
          BoxShadow(
            color: theme.appColors.cardShadow,
            spreadRadius: 0,
            blurRadius: 40,
            offset: Offset(0, 1),
          ),
        ],
      ),

      child: Row(
        spacing: 16,
        children: [
          _DotColor(tag: tag),
          Expanded(
            child: Column(
              mainAxisSize: .min,
              crossAxisAlignment: .start,
              children: [
                Text(tag.name, overflow: .ellipsis),
                Text(
                  _countUser(tag.usageCount),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          _MenuDeAcoes(tag: tag, onEdit: onEdit, onDelete: onDelete),
        ],
      ),
    );
  }
}

enum _Acao { editar, excluir }

class _MenuDeAcoes extends StatelessWidget {
  const _MenuDeAcoes({
    required this.tag,
    required this.onEdit,
    required this.onDelete,
  });

  final TagModel tag;
  final void Function(TagModel tag)? onEdit;
  final void Function(TagModel tag)? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopupMenuButton<_Acao>(
      icon: const Icon(Icons.more_vert),
      tooltip: 'Mais opções',
      padding: .zero,
      style: IconButton.styleFrom(
        padding: .zero,
        minimumSize: const Size(24, 24),
        tapTargetSize: .shrinkWrap,
      ),
      enabled: onEdit != null || onDelete != null,
      onSelected: (acao) {
        switch (acao) {
          case .editar:
            onEdit?.call(tag);
          case .excluir:
            onDelete?.call(tag);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: .editar,
          child: ListTile(
            contentPadding: .zero,
            leading: Icon(Icons.edit_outlined),
            title: Text('Editar'),
          ),
        ),
        PopupMenuItem(
          value: .excluir,
          child: ListTile(
            contentPadding: .zero,
            iconColor: theme.colorScheme.error,
            textColor: theme.colorScheme.error,
            leading: Icon(Icons.delete_outline),
            title: Text('Excluir'),
          ),
        ),
      ],
    );
  }
}

class _DotColor extends StatelessWidget {
  const _DotColor({required this.tag});

  final TagModel tag;

  @override
  Widget build(BuildContext context) {
    // A inicial em cinza, que aparecia quando a tag não tinha cor, saiu com a
    // TAG-02: não existe mais tag sem cor para cair nela.
    return CircleAvatar(backgroundColor: TagColor.parse(tag.color), radius: 10);
  }
}
