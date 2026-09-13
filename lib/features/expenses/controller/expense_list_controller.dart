import 'package:signals/signals.dart';

import '../../../data/services/selected_month_service.dart';
import '../../../core/shared/view_state.dart';
import '../../../core/utils/base_controller.dart';
import '../../../data/models/expense_model.dart';
import '../../../data/repositories/expense_repository.dart';
import 'package:se_controle_ai/data/enums/payment_method.dart';

/// Lista de gastos. Mesmo molde do `IncomeListController`: signal privado,
/// getter `ReadonlySignal`, nenhum import de Flutter.
///
/// A listagem é **sem `?month`** e **com `?activeFrom`**, e a diferença entre os
/// dois é a tela inteira:
///
/// - sem `?month`, o backend devolve `amountCents: null` em todos (GFX-10 ao
///   contrário) e o valor exibido sai do `history` — ver
///   `ExpenseModel.amountCentsIn`. É o que permite mostrar o gasto que ainda vai
///   começar, que num recorte por competência não existiria;
/// - com `?activeFrom` no mês selecionado, some o que **acabou antes** dele
///   (GFX-11). O 99 food avulso de setembro não é assunto em outubro: ele já foi
///   cobrado, não sai de novo, e reaparecer com o selo "Encerrado" só enche a
///   lista de coisa que não vai acontecer. Aqui devem ficar o recorrente, o
///   parcelado em curso e o que foi lançado neste mês.
///
/// Voltar para setembro traz o de setembro de volta, porque lá ele estava
/// mesmo sendo cobrado — o que o filtro esconde é passado, nunca cadastro
/// perdido. Para apagar um gasto antigo, basta ir ao mês dele.
class ExpenseListController extends BaseController {
  ExpenseListController(this._repository, this._selectedMonth);

  final ExpenseRepository _repository;
  final SelectedMonthService _selectedMonth;

  EffectCleanup? _watchingMonth;

  final _state = signal<ViewState<List<ExpenseModel>>>(const Loading());

  /// Filtro por forma de pagamento, ou nulo para a lista inteira.
  ///
  /// **Entra por [applyFilter], não pelo construtor.** Ele vem da query da rota
  /// (`/expenses?paymentMethod=DEBIT`), e dado de rota é assunto da view — o
  /// construtor daqui só recebe dependência. É também o que permite este
  /// controller continuar sendo um singleton: a mesma tela serve a lista
  /// completa e o recorte de dinheiro, trocando o filtro em vez de trocar de
  /// controller.
  PaymentMethod? _paymentMethod;

  PaymentMethod? get paymentMethod => _paymentMethod;

  /// Cresce a cada requisição. Serve para descartar resposta atrasada — mesmo
  /// contador do `HomeController`.
  int _requestId = 0;

  ReadonlySignal<ViewState<List<ExpenseModel>>> get state => _state;

  /// A inscrição no mês **é** a carga inicial, como na lista de cartões: o
  /// `effect` roda uma vez ao ser criado e de novo a cada troca de mês na home.
  /// Um `load()` aqui além dele só duplicaria a primeira requisição.
  @override
  void onInit() {
    super.onInit();

    _watchingMonth = effect(() {
      _selectedMonth.month.value;
      // `untracked` para o efeito depender **só** do mês: sem ele, qualquer
      // signal que o `load` venha a ler vira dependência sem querer.
      untracked(load);
    });
  }

  /// Troca o filtro e rebusca, se ele mudou.
  ///
  /// Quem chama é a view, no `initState` — inclusive com nulo, que é o que
  /// devolve a lista completa depois de uma visita ao recorte. Sem a guarda de
  /// igualdade, toda entrada na tela custaria uma requisição a mais.
  Future<void> applyFilter(PaymentMethod? paymentMethod) async {
    if (_paymentMethod == paymentMethod) return;

    _paymentMethod = paymentMethod;
    await load();
  }

  /// [silent] mantém a lista na tela durante a busca, para o pull-to-refresh
  /// não piscar e para a volta de uma ação não apagar o conteúdo.
  Future<void> load({bool silent = false}) async {
    final requestId = ++_requestId;

    if (!silent) _state.value = const Loading();

    final result = await _repository.list(
      activeFrom: _selectedMonth.month.value,
      paymentMethod: _paymentMethod,
    );

    // Duas buscas em voo podem voltar fora de ordem — um refresh depois de uma
    // ação, disparado enquanto a busca anterior ainda não voltou, é o caso
    // real. Sem esta guarda a resposta velha sobrescreveria a nova.
    if (requestId != _requestId) return;

    result.when(
      (success) => _state.value = Loaded(success),
      (err) => _state.value = Failed(err),
    );
  }

  Future<void> refresh() => load(silent: true);

  @override
  void dispose() {
    _watchingMonth?.call();
    _state.dispose();
    super.dispose();
  }
}
