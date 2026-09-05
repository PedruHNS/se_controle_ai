import 'package:flutter/material.dart';
import 'package:se_controle_ai/data/services/navigation_service.dart';
import 'package:se_controle_ai/features/tags/widgets/create_tag_dialog_widget.dart';
import 'package:se_controle_ai/features/tags/widgets/tag_tile_widget.dart';
import 'package:signals/signals_flutter.dart';
import '../../../core/di/injector.dart';
import '../../../core/shared/view_state.dart';
import '../../../core/shared/widgets/empty_state_widget.dart';
import '../../../core/shared/widgets/failure_card_widget.dart';
import '../../../data/models/tag_model.dart';
import '../controller/tag_list_controller.dart';

import 'package:skeletonizer/skeletonizer.dart';

class TagListPage extends StatefulWidget {
  const TagListPage({super.key});

  @override
  State<TagListPage> createState() => _TagListPageState();
}

class _TagListPageState extends State<TagListPage> {
  final _controller = getIt<TagListController>();
  final _nav = getIt<NavigationService>();

  Future<void> _create() async {
    await showDialog(
      context: context,
      builder: (context) => CreateTagDialogWidget(),
    );
  }

  Future<void> _onDelete(TagModel tag) async {
    await showDialog(
      context: context,
      builder: (context) => _DeleteDialog(
        tag: tag,
        cancel: () => _nav.pop(),
        confirm: () async => await _controller.delete(tag),
      ),
    );
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
              onEdit: (tag) {
                showDialog(
                  context: context,
                  builder: (context) => CreateTagDialogWidget(tag: tag),
                );
              },
              onDelete: _onDelete,
            ),
          };
        },
      ),

      floatingActionButton: SignalBuilder(
        builder: (context) => Visibility(
          visible: _controller.state.value is Loaded,
          child: FloatingActionButton(
            onPressed: _create,
            child: const Icon(Icons.add),
          ),
        ),
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
    final paddingBottom = MediaQuery.paddingOf(context).bottom;
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
        padding: .fromLTRB(24, 24, 24, paddingBottom + 80),
        itemCount: tags.length,
        itemBuilder: (_, i) {
          return TagTile(tag: tags[i], onEdit: onEdit, onDelete: onDelete);
        },
      ),
    );
  }
}

class _DeleteDialog extends StatelessWidget {
  final TagModel tag;
  final void Function() cancel;
  final void Function() confirm;
  const _DeleteDialog({
    required this.tag,
    required this.cancel,
    required this.confirm,
  });

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
        TextButton(onPressed: cancel, child: const Text('Cancelar')),
        FilledButton(onPressed: confirm, child: Text('Confirmar')),
      ],
    );
  }
}
