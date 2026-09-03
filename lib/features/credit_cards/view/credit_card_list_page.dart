import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:se_controle_ai/data/services/navigation_service.dart';
import 'package:signals/signals_flutter.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../core/di/injector.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/shared/view_state.dart';
import '../../../core/shared/widgets/empty_state_widget.dart';
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
  final _nav = getIt<NavigationService>();

  Future<void> _confirmDelete(CreditCardModel card) async {
    showDialog<void>(
      context: context,
      builder: (context) {
        return _DeleteDialog(
          card: card,
          onConfirm: () async {
            await _controller.delete(card.id);
            _nav.pop();
          },
          onCancel: () => _nav.pop(),
        );
      },
    );
  }

  @override
  void dispose() {
    super.dispose();
    getIt.resetLazySingleton<CreditCardListController>();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cartões'), centerTitle: true),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _nav.pushNamed(AppRoutes.creditCardForm),
        child: const Icon(Icons.add),
      ),
      body: SignalBuilder(
        builder: (context) {
          final state = _controller.state.value;

          return switch (state) {
            Loading() => ListView.separated(
              padding: .all(24),
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemCount: 6,
              itemBuilder: (_, _) =>
                  Skeletonizer(child: CreditCardWidget.esqueleton()),
            ),
            Failed(failure: final failure) => Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FailureCardWidget(
                  failure: failure,
                  onRetry: _controller.refresh,
                ),
              ),
            ),
            Loaded(data: final cards) => _CreditCardList(
              cards: cards,
              onRefresh: _controller.refresh,
              onOpen: (card) => _nav.pushNamed(
                AppRoutes.creditCardExpenses,
                pathParameters: {RouteParams.id: card.id},
              ),

              onDelete: _confirmDelete,
            ),
          };
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
    if (cards.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.credit_card,
        title: 'Nenhum cartão cadastrado',
        message: 'Cadastre um para poder lançar gasto no cartão.',
        onRefresh: onRefresh,
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        padding: .all(24),
        itemCount: cards.length,
        itemBuilder: (_, i) {
          return CreditCardWidget(
            card: cards[i],
            onTap: () => onOpen(cards[i]),
            onDelete: () => onDelete(cards[i]),
          );
        },
      ),
    );
  }
}

class _DeleteDialog extends StatelessWidget {
  const _DeleteDialog({
    required this.card,
    required this.onConfirm,
    required this.onCancel,
  });

  final CreditCardModel card;
  final Future<void> Function() onConfirm;
  final void Function() onCancel;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Excluir cartão'),
      content: Text('${card.label} sai do cadastro.'),
      actions: [
        TextButton(onPressed: onCancel, child: const Text('Cancelar')),
        FilledButton(onPressed: onConfirm, child: const Text('Excluir')),
      ],
    );
  }
}
