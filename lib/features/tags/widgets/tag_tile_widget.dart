import 'package:flutter/material.dart';
import 'package:se_controle_ai/data/models/tag_model.dart';

class TagTile extends StatelessWidget {
  final TagModel tag;
  final void Function(TagModel tag)? onEdit;
  final void Function(TagModel tag)? onDelete;

  const TagTile({super.key, required this.tag, this.onEdit, this.onDelete});

  const TagTile.esqueleto({super.key})
    : tag = const TagModel(
        id: '',
        name: 'Categoria',
        color: null,
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
        color: Colors.white,
        borderRadius: .circular(10),
        boxShadow: [
          BoxShadow(
            color: .fromRGBO(57, 51, 96, 0.1),
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

/// Os três pontinhos no fim da linha.
///
/// **Um item só para sair de circulação, e quem decide o desfecho é o
/// backend** (TAG-08): `DELETE` numa tag em uso arquiva, numa tag sem uso apaga.
///
/// O menu não tenta adivinhar qual dos dois vai acontecer. Quem conta é o
/// diálogo de confirmação — que já muda o título entre "Arquivar tag" e
/// "Excluir tag" pelo uso — e, depois, a mensagem com o desfecho real. Duplicar
/// esse palpite aqui só criaria um rótulo que erra quando o `usageCount` está
/// velho.
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
    return PopupMenuButton(
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
          value: _Acao.editar,
          child: ListTile(
            contentPadding: .zero,
            leading: Icon(Icons.edit_outlined),
            title: Text('Editar'),
          ),
        ),
        PopupMenuItem(
          value: _Acao.excluir,
          child: ListTile(
            contentPadding: .zero,
            // Vermelho porque é o item que pode não ter volta. O Arquivar
            // fica neutro: quando ele de fato arquiva, o Restaurar desfaz.
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
    final theme = Theme.of(context);
    final color = tag.parsedColor;

    if (color == null) {
      return CircleAvatar(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        radius: 10,
        child: Text(
          tag.name.characters.first.toUpperCase(),
          style: theme.textTheme.titleSmall,
        ),
      );
    }

    return CircleAvatar(backgroundColor: color, radius: 10);
  }
}
