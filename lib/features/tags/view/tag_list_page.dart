import 'package:flutter/material.dart';
import 'package:se_controle_ai/features/tags/widgets/create_tag_dialog_widget.dart';
import 'package:se_controle_ai/features/tags/widgets/tag_tile_widget.dart';
import 'package:signals/signals_flutter.dart';

import '../../../core/di/injector.dart';
import '../../../core/errors/failure.dart';

import '../../../core/shared/view_state.dart';
import '../../../core/shared/widgets/empty_state_widget.dart';
import '../../../core/shared/widgets/failure_card_widget.dart';
import '../../../data/models/tag_model.dart';
import '../controller/tag_list_controller.dart';

import 'package:skeletonizer/skeletonizer.dart';

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
    showDialog(context: context, builder: (context) => CreateTagDialogWidget());
  }

  // Future<void> _edit(TagModel tag) async {
  //   final alterado = await showTagFormDialog(context, tag: tag);
  //   if (alterado == null || !mounted) return;

  //   // Sair sem mexer em nada seria um PATCH de corpo vazio, que o backend
  //   // recusa com 400 — e prender quem só abriu e fechou seria absurdo.
  //   if (alterado.name == tag.name && alterado.color == tag.color) return;

  //   final failure = await _controller.update(
  //     tag.id,
  //     name: alterado.name == tag.name ? null : alterado.name,
  //     // Patch e não `String?`: aqui `null` significa "tirei a cor", e sem essa
  //     // distinção limpar seria indistinguível de não ter tocado.
  //     color: Patch<String>.diff(alterado.color, tag.color),
  //   );

  //   _reportIfFailed(failure);
  // }

  // Future<void> _confirmDelete(TagModel tag) async {
  //   final confirmou = await showDialog<bool>(
  //     context: context,
  //     builder: (context) => _DeleteDialog(tag: tag),
  //   );

  //   if (confirmou != true || !mounted) return;

  //   final resultado = await _controller.delete(tag.id);

  //   if (!mounted) return;

  //   if (resultado.failure != null) {
  //     _reportIfFailed(resultado.failure);
  //     return;
  //   }

  //   // "Excluída" e "arquivada" não são a mesma notícia, e quem apertou Excluir
  //   // precisa saber que a tag continua existindo nos lançamentos antigos.
  //   ScaffoldMessenger.of(context).showSnackBar(
  //     SnackBar(
  //       content: Text(
  //         resultado.archived
  //             ? '${tag.name} foi arquivada e continua nos lançamentos antigos.'
  //             : '${tag.name} foi excluída.',
  //       ),
  //     ),
  //   );
  // }

  void _reportIfFailed(Failure? failure) {
    if (!mounted || failure == null) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(failure.message)));
  }

  @override
  void dispose() {
    getIt.resetLazySingleton<TagListController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tags'), centerTitle: true),
      floatingActionButton: SignalBuilder(
        builder: (context) => FloatingActionButton(
          onPressed: _controller.working.value ? null : _create,
          child: const Icon(Icons.add),
        ),
      ),
      body: SignalBuilder(
        builder: (context) {
          final state = _controller.state.value;
          return switch (state) {
            Loading() => ListView.separated(
              padding: .all(24),
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemCount: 6,
              itemBuilder: (_, _) => Skeletonizer(child: TagTile.esqueleto()),
            ),
            Failed(failure: final failure) => Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FailureCardWidget(
                  failure: failure,
                  onRetry: () => _controller.refresh(),
                ),
              ),
            ),
            Loaded(data: final tags) => _TagList(
              tags: tags,
              onRefresh: _controller.refresh,
              onEdit: (tag) {},
              onDelete: (tag) {},
            ),
          };
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
  });

  final List<TagModel> tags;
  final Future<void> Function() onRefresh;
  final void Function(TagModel tag) onEdit;
  final void Function(TagModel tag) onDelete;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.sell_outlined,
        title: 'Nenhuma tag cadastrada',
        message:
            'Todo gasto precisa de uma. Cadastre a primeira para poder lançar.',
        onRefresh: onRefresh,
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,

      child: ListView.separated(
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        padding: .all(24),
        itemCount: tags.length,
        itemBuilder: (_, i) {
          return TagTile(tag: tags[i], onEdit: onEdit, onDelete: onDelete);
        },
      ),
    );
  }
}

/// O ponto de cor da tag. Sem cor, mostra a inicial — um círculo cinza
/// sugeriria que a cor escolhida foi cinza.

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
  final TagModel tag;
  const _DeleteDialog({required this.tag});

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
            ? '$lancamentos "${tag.name}". Ela continua neles, mas sai das opções de gasto e ganho novos. caso precise voltar com essa tag apenas crie ela novamente.'
            : '"${tag.name}" não é usada por nenhum lançamento e será excluída.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text('Excluir'),
        ),
      ],
    );
  }
}
