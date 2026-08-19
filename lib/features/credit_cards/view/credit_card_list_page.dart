import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:signals/signals_flutter.dart';

import '../../../core/di/injector.dart';
import '../../../core/errors/failure.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/shared/view_state.dart';
import '../../../core/shared/widgets/failure_card_widget.dart';
import '../../../data/models/credit_card_model.dart';
import '../controller/credit_card_list_controller.dart';
import '../widgets/credit_card_tile.dart';

/// Lista de cartões — a porta de entrada do CRUD.
class CreditCardListPage extends StatefulWidget {
  const CreditCardListPage({super.key});

  @override
  State<CreditCardListPage> createState() => _CreditCardListPageState();
}

class _CreditCardListPageState extends State<CreditCardListPage> {
  final _controller = getIt<CreditCardListController>();

  /// Recarrega ao voltar do formulário: ele pode ter criado ou editado, e a
  /// lista não fica sabendo sozinha.
  Future<void> _openAndReload(Future<Object?> navigation) async {
    await navigation;
    if (!mounted) return;
    await _controller.refresh();
  }

  Future<void> _confirmDelete(CreditCardModel card) async {
    final failure = await showDialog<Failure?>(
      context: context,
      builder: (context) => _DeleteDialog(
        card: card,
        onConfirm: () => _controller.delete(card.id),
      ),
    );

    if (!mounted || failure == null) return;

    // Chega aqui o que o diálogo não soube explicar — rede, 500. O 409 do
    // CAR-07 fica no próprio diálogo, que é onde a pergunta foi feita.
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(failure.message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cartões'), centerTitle: true),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            _openAndReload(context.pushNamed(AppRoutes.creditCardForm)),
        icon: const Icon(Icons.add),
        label: const Text('Novo cartão'),
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
          Loaded(data: final cards) => _CreditCardList(
            cards: cards,
            onRefresh: _controller.refresh,
            onOpen: (card) => _openAndReload(
              context.pushNamed(
                AppRoutes.creditCardEdit,
                pathParameters: {RouteParams.id: card.id},
              ),
            ),
            onDelete: _confirmDelete,
          ),
        },
      ),
    );
  }
}

class _CreditCardList extends StatelessWidget {
  const _CreditCardList({
    required this.cards,
    required this.onRefresh,
    required this.onOpen,
    required this.onDelete,
  });

  final List<CreditCardModel> cards;
  final Future<void> Function() onRefresh;
  final void Function(CreditCardModel card) onOpen;
  final void Function(CreditCardModel card) onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (cards.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.25),
            Icon(
              Icons.credit_card,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'Nenhum cartão cadastrado',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Cadastre um para poder lançar gasto no cartão.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        // Espaço no fim para o FAB não cobrir o último item.
        padding: const EdgeInsets.only(bottom: 88),
        itemCount: cards.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final card = cards[index];
          return CreditCardTile(
            card: card,
            onTap: () => onOpen(card),
            onDelete: () => onDelete(card),
          );
        },
      ),
    );
  }
}

/// Confirmação de exclusão, e o lugar onde o 409 do CAR-07 aparece.
///
/// O erro fica **dentro** do diálogo em vez de fechar e virar snackbar: "este
/// cartão tem gastos vinculados" é resposta à pergunta que o diálogo faz, e o
/// cartão continua ali, na lista de trás, sem ter sido tocado.
class _DeleteDialog extends StatefulWidget {
  const _DeleteDialog({required this.card, required this.onConfirm});

  final CreditCardModel card;
  final Future<Failure?> Function() onConfirm;

  @override
  State<_DeleteDialog> createState() => _DeleteDialogState();
}

class _DeleteDialogState extends State<_DeleteDialog> {
  Failure? _failure;
  bool _working = false;

  Future<void> _confirm() async {
    setState(() {
      _working = true;
      _failure = null;
    });

    final failure = await widget.onConfirm();

    if (!mounted) return;

    // Conflito é explicação, não erro de sistema: fica aqui. O resto sobe para
    // quem abriu o diálogo virar snackbar.
    if (failure is ConflictFailure) {
      setState(() {
        _working = false;
        _failure = failure;
      });
      return;
    }

    Navigator.of(context).pop(failure);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final failure = _failure;

    return AlertDialog(
      title: const Text('Excluir cartão'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${widget.card.label} sai do cadastro.'),
          if (failure != null) ...[
            const SizedBox(height: 12),
            Text(
              failure.message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _working ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _working ? null : _confirm,
          child: _working
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Excluir'),
        ),
      ],
    );
  }
}
