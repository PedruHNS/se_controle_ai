import 'package:signals/signals.dart';

import '../../../core/errors/failure.dart';
import '../../../core/shared/view_state.dart';
import '../../../core/utils/base_controller.dart';
import '../../../data/models/expense_model.dart';
import '../../../data/repositories/credit_card_repository.dart';
import '../../../data/repositories/expense_repository.dart';

/// Um gasto e suas operações.
///
/// **As de dinheiro dependem do tipo, e não se misturam** (GPR-17): fixo
/// reajusta, corrige e encerra; parcelado reparcela e quita. O backend recusa a
/// troca com 422 — "Reajuste só se aplica a gasto fixo. Em um parcelado, use o
/// reparcelamento" —, e a tela some com o que não cabe em vez de deixar a
/// pessoa levar o erro.
///
/// As três primeiras devolvem `Failure?` em vez de guardarem o erro num signal:
/// elas são disparadas de dentro de um diálogo, e é lá que o erro precisa
/// aparecer — inclusive o 422 de regra de negócio, que traz a mensagem pronta
/// do backend ("Reajuste precisa valer de 2026-08 em diante...").
///
/// **O id não entra pelo construtor.** Ele é dado da rota, então quem o conhece
/// é a view: ela chama [start] no `initState` com o que veio em
/// `pathParameters`.
class ExpenseDetailController extends BaseController {
  ExpenseDetailController(this._repository, this._cardRepository);

  final ExpenseRepository _repository;
  final CreditCardRepository _cardRepository;

  late String _id;

  String get id => _id;

  final _state = signal<ViewState<ExpenseModel>>(const Loading());
  final _working = signal<bool>(false);
  final _cardLabel = signal<String?>(null);

  /// Cresce a cada requisição, para descartar resposta atrasada — ver [load].
  int _requestId = 0;

  ReadonlySignal<ViewState<ExpenseModel>> get state => _state;

  /// Alguma operação em andamento — a view desabilita os botões para não
  /// disparar duas vezes.
  ReadonlySignal<bool> get working => _working;

  /// O nome do cartão do gasto, quando é no cartão e a busca deu certo.
  ///
  /// É **best-effort**: o gasto já está na tela sem isto, e uma falha ao buscar
  /// o cartão não pode virar tela de erro para um dado decorativo. Nesse caso a
  /// tela diz só "No cartão".
  ReadonlySignal<String?> get cardLabel => _cardLabel;

  /// Recebe o id da rota e faz a primeira busca.
  Future<void> start(String id) {
    _id = id;
    return load();
  }

  Future<void> load({bool silent = false}) async {
    final requestId = ++_requestId;

    if (!silent) _state.value = const Loading();

    final result = await _repository.getById(id);

    // Cada ação termina numa recarga silenciosa, então duas ações em sequência
    // rápida deixam duas buscas em voo. Sem esta guarda, a que voltar por
    // último manda — e não é necessariamente a mais nova.
    if (requestId != _requestId) return;

    final expense = result.when<ExpenseModel?>(
      (success) {
        _state.value = Loaded(success);
        return success;
      },
      (err) {
        _state.value = Failed(err);
        return null;
      },
    );

    if (expense == null) return;

    // Depois de o estado ir para `Loaded`, e aguardado: a tela já está montada
    // com o gasto quando esta busca começa, e quem chamou `load` só continua
    // quando a tela está inteira — é o que torna o teste determinístico sem
    // precisar de `pump` com duração adivinhada.
    await _loadCardLabel(expense);
  }

  Future<void> _loadCardLabel(ExpenseModel expense) async {
    final cardId = expense.creditCardId;

    if (cardId == null) {
      _cardLabel.value = null;
      return;
    }

    // Já temos o nome deste cartão de uma carga anterior: recarregar depois de
    // um reajuste não precisa perguntar de novo.
    if (_cardLabel.value != null && cardId == _lastCardId) return;

    _lastCardId = cardId;

    final result = await _cardRepository.getById(cardId);
    result.when(
      (card) => _cardLabel.value = card.label,
      (_) => _cardLabel.value = null,
    );
  }

  String? _lastCardId;

  Future<void> refresh() => load(silent: true);

  /// Reajuste — o valor novo passa a valer de [effectiveFrom] em diante, e os
  /// meses anteriores ficam como estavam.
  Future<Failure?> adjust({
    required int amountCents,
    required String effectiveFrom,
  }) async {
    _working.value = true;

    final result = await _repository.adjust(
      id,
      amountCents: amountCents,
      effectiveFrom: effectiveFrom,
    );

    _working.value = false;

    return result.when((_) async {
      await load(silent: true);
      return null;
    }, (error) async => error);
  }

  /// Correção — o valor estava errado desde o início da vigência atual.
  Future<Failure?> correct({required int amountCents}) async {
    _working.value = true;

    final result = await _repository.correct(id, amountCents: amountCents);

    _working.value = false;

    return result.when((_) async {
      await load(silent: true);
      return null;
    }, (error) async => error);
  }

  /// Encerramento — [lastMonth] é a última competência cobrada.
  Future<Failure?> close({required String lastMonth}) async {
    _working.value = true;

    final result = await _repository.close(id, lastMonth: lastMonth);

    _working.value = false;

    return result.when((_) async {
      await load(silent: true);
      return null;
    }, (error) async => error);
  }

  /// Reparcelamento — refaz o plano de [fromMonth] em diante. Os dois números
  /// são totais da compra, não o que falta (GPR-07/GPR-08).
  Future<Failure?> reschedule({
    required int newTotalCents,
    required int newInstallmentsCount,
    required String fromMonth,
  }) async {
    _working.value = true;

    final result = await _repository.reschedule(
      id,
      newTotalCents: newTotalCents,
      newInstallmentsCount: newInstallmentsCount,
      fromMonth: fromMonth,
    );

    _working.value = false;

    return result.when((_) async {
      await load(silent: true);
      return null;
    }, (error) async => error);
  }

  /// Quitação — apaga as parcelas de [fromMonth] em diante (GPR-14).
  Future<Failure?> settle({required String fromMonth}) async {
    _working.value = true;

    final result = await _repository.settle(id, fromMonth: fromMonth);

    _working.value = false;

    return result.when((_) async {
      await load(silent: true);
      return null;
    }, (error) async => error);
  }

  /// Exclusão. Sem recarregar depois: o gasto deixou de existir, e quem chamou
  /// sai da tela.
  Future<Failure?> delete() async {
    _working.value = true;

    final result = await _repository.delete(id);

    _working.value = false;

    return result.when((_) async => null, (error) async => error);
  }

  @override
  void dispose() {
    _state.dispose();
    _working.dispose();
    _cardLabel.dispose();
    super.dispose();
  }
}
