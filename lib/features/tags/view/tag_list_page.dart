import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';

import '../../../core/di/injector.dart';
import '../../../core/errors/failure.dart';
import '../../../core/shared/patch.dart';
import '../../../core/shared/view_state.dart';
import '../../../core/shared/widgets/failure_card_widget.dart';
import '../../../data/models/tag_model.dart';
import '../controller/tag_list_controller.dart';
import '../widgets/tag_form_dialog.dart';

/// Tags — o CRUD completo, sem tela de detalhe nem formulário de página
/// inteira.
///
/// A tag tem dois campos, nome e cor, e nenhum histórico: uma tela cheia para
/// isso seria navegação sem conteúdo. Criar e editar acontecem em diálogo,
/// sobre a lista, que se atualiza atrás.
class TagListPage extends StatefulWidget {
  const TagListPage({super.key});

  @override
  State<TagListPage> createState() => _TagListPageState();
}

class _TagListPageState extends State<TagListPage> {
  final _controller = getIt<TagListController>();

  Future<void> _create() async {
    final novo = await showTagFormDialog(context);
    if (novo == null || !mounted) return;

    final failure = await _controller.create(
      name: novo.name,
      color: novo.color,
    );

    _reportIfFailed(failure);
  }

  Future<void> _edit(TagModel tag) async {
    final alterado = await showTagFormDialog(context, tag: tag);
    if (alterado == null || !mounted) return;

    // Sair sem mexer em nada seria um PATCH de corpo vazio, que o backend
    // recusa com 400 — e prender quem só abriu e fechou seria absurdo.
    if (alterado.name == tag.name && alterado.color == tag.color) return;

    final failure = await _controller.update(
      tag.id,
      name: alterado.name == tag.name ? null : alterado.name,
      // Patch e não `String?`: aqui `null` significa "tirei a cor", e sem essa
      // distinção limpar seria indistinguível de não ter tocado.
      color: Patch<String>.diff(alterado.color, tag.color),
    );

    _reportIfFailed(failure);
  }

  Future<void> _confirmDelete(TagModel tag) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => _DeleteDialog(tag: tag),
    );

    if (confirmou != true || !mounted) return;

    final resultado = await _controller.delete(tag.id);

    if (!mounted) return;

    if (resultado.failure != null) {
      _reportIfFailed(resultado.failure);
      return;
    }

    // "Excluída" e "arquivada" não são a mesma notícia, e quem apertou Excluir
    // precisa saber que a tag continua existindo nos lançamentos antigos.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          resultado.archived
              ? '${tag.name} foi arquivada e continua nos lançamentos antigos.'
              : '${tag.name} foi excluída.',
        ),
      ),
    );
  }

  Future<void> _restore(TagModel tag) async {
    final failure = await _controller.restore(tag.id);
    _reportIfFailed(failure);
  }

  void _reportIfFailed(Failure? failure) {
    if (!mounted || failure == null) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(failure.message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tags'), centerTitle: true),
      floatingActionButton: SignalBuilder(
        builder: (context) => FloatingActionButton.extended(
          onPressed: _controller.working.value ? null : _create,
          icon: const Icon(Icons.add),
          label: const Text('Nova tag'),
        ),
      ),
      body: SignalBuilder(
        builder: (context) => switch (_controller.state.value) {
          Loading() => const Center(child: CircularProgressIndicator()),
          Failed(failure: final failure) => Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FailureCardWidget(
                failure: failure,
                onRetry: _controller.load,
              ),
            ),
          ),
          Loaded(data: final tags) => _TagList(
            tags: tags,
            onRefresh: _controller.refresh,
            onEdit: _edit,
            onDelete: _confirmDelete,
            onRestore: _restore,
          ),
        },
      ),
    );
  }
}

class _TagList extends StatelessWidget {
  const _TagList({
    required this.tags,
    required this.onRefresh,
    required this.onEdit,
    required this.onDelete,
    required this.onRestore,
  });

  final List<TagModel> tags;
  final Future<void> Function() onRefresh;
  final void Function(TagModel tag) onEdit;
  final void Function(TagModel tag) onDelete;
  final void Function(TagModel tag) onRestore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (tags.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.25),
            Icon(
              Icons.sell_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'Nenhuma tag cadastrada',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Todo gasto precisa de uma. Cadastre a primeira para poder '
              'lançar.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    // Arquivadas embaixo, em seção própria: elas não servem para lançar, então
    // misturá-las com as ativas atrapalharia justamente quem veio cadastrar.
    final ativas = tags.where((tag) => !tag.archived).toList();
    final arquivadas = tags.where((tag) => tag.archived).toList();

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        // Espaço no fim para o FAB não cobrir a última linha.
        padding: const EdgeInsets.only(bottom: 88),
        children: [
          for (final tag in ativas) ...[
            _TagTile(tag: tag, onEdit: onEdit, onDelete: onDelete),
            const Divider(height: 1),
          ],
          if (arquivadas.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Text(
                'Arquivadas',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                'Continuam nos lançamentos que já as usam, mas não podem ser '
                'escolhidas em lançamento novo.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            for (final tag in arquivadas) ...[
              _TagTile(
                tag: tag,
                onEdit: onEdit,
                onDelete: onDelete,
                onRestore: onRestore,
              ),
              const Divider(height: 1),
            ],
          ],
        ],
      ),
    );
  }
}

class _TagTile extends StatelessWidget {
  const _TagTile({
    required this.tag,
    required this.onEdit,
    required this.onDelete,
    this.onRestore,
  });

  final TagModel tag;
  final void Function(TagModel tag) onEdit;
  final void Function(TagModel tag) onDelete;

  /// Só as arquivadas têm o que restaurar.
  final void Function(TagModel tag)? onRestore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final restore = onRestore;

    return ListTile(
      leading: _ColorAvatar(tag: tag),
      title: Text(
        tag.name,
        style: tag.archived
            ? TextStyle(color: theme.colorScheme.onSurfaceVariant)
            : null,
      ),
      subtitle: Text(
        switch (tag.usageCount) {
          0 => 'Sem uso',
          1 => '1 lançamento',
          final n => '$n lançamentos',
        },
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      // O toque abre a edição: não há tela de detalhe para onde ir, e a tag
      // não tem nada a mostrar além do que já está na linha. Renomear vale
      // para trás (TAG-03), inclusive na arquivada.
      onTap: () => onEdit(tag),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (restore != null)
            IconButton(
              icon: const Icon(Icons.unarchive_outlined),
              tooltip: 'Restaurar',
              onPressed: () => restore(tag),
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: tag.archived ? 'Excluir de vez' : 'Excluir',
            onPressed: () => onDelete(tag),
          ),
        ],
      ),
    );
  }
}

/// O ponto de cor da tag. Sem cor, mostra a inicial — um círculo cinza
/// sugeriria que a cor escolhida foi cinza.
class _ColorAvatar extends StatelessWidget {
  const _ColorAvatar({required this.tag});

  final TagModel tag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = tag.parsedColor;

    if (color == null) {
      return CircleAvatar(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        child: Text(
          tag.name.characters.first.toUpperCase(),
          style: theme.textTheme.titleSmall,
        ),
      );
    }

    return CircleAvatar(backgroundColor: color, radius: 16);
  }
}

/// Confirmação de exclusão, que diz **antes** o que vai acontecer.
///
/// São dois desfechos (TAG-08) e a diferença importa para quem decide: tag sem
/// uso é apagada, tag em uso é arquivada e continua nos lançamentos antigos.
/// Descobrir isso só depois, pela mensagem de sucesso, seria decidir no escuro.
///
/// Não fala com o repositório: devolve `true` e quem chamou executa. É o
/// oposto do diálogo de cartão, e a razão é que aqui não há erro esperado para
/// mostrar dentro dele — o 409 da TAG-08 deixou de existir.
class _DeleteDialog extends StatelessWidget {
  const _DeleteDialog({required this.tag});

  final TagModel tag;

  @override
  Widget build(BuildContext context) {
    final emUso = tag.usageCount > 0;
    final lancamentos = tag.usageCount == 1
        ? '1 lançamento usa'
        : '${tag.usageCount} lançamentos usam';

    return AlertDialog(
      title: Text(emUso ? 'Arquivar tag' : 'Excluir tag'),
      content: Text(
        emUso
            ? '$lancamentos "${tag.name}". Ela continua neles, mas sai das '
                  'opções de gasto e ganho novos. Dá para restaurar depois.'
            : '"${tag.name}" não é usada por nenhum lançamento e será excluída.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(emUso ? 'Arquivar' : 'Excluir'),
        ),
      ],
    );
  }
}
