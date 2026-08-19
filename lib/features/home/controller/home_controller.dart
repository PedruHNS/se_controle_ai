import 'package:se_controle_ai/core/utils/base_controller.dart';
import 'package:signals/signals.dart';

import '../../../core/shared/view_state.dart';
import '../../../core/utils/month.dart';
import '../../../data/models/monthly_summary_model.dart';
import '../../../data/repositories/summary_repository.dart';

/// Estado do resumo mensal.
///
/// Padrão a repetir nas próximas features:
///
/// - `signal` privado, getter `ReadonlySignal` público. A view lê, só o
///   controller escreve — assim não aparece `controller.state.value = ...`
///   espalhado por widget.
/// - `computed` para o que é derivado. Não guarde rótulo formatado em signal
///   próprio: ele sairia de sincronia com a fonte na primeira distração.
/// - nenhum `import` de Flutter aqui. O controller é testável sem `pumpWidget`.
class HomeController extends BaseController {
  HomeController(this._repository);

  final SummaryRepository _repository;

  final _state = signal<ViewState<MonthlySummaryModel>>(const Loading());
  final _month = signal<String>(Month.current());

  /// Cresce a cada requisição. Serve para descartar resposta atrasada — ver
  /// [load].
  int _requestId = 0;

  ReadonlySignal<ViewState<MonthlySummaryModel>> get state => _state;
  ReadonlySignal<String> get month => _month;

  /// `'Agosto 2026'`. Derivado de [month]: trocar o mês reformata sozinho.
  late final ReadonlySignal<String> monthLabel = computed(
    () => Month.label(_month.value),
  );

  /// A competência exibida é a de hoje? A UI usa para destacar o "hoje" e
  /// habilitar um atalho de voltar ao mês corrente.
  late final ReadonlySignal<bool> isCurrentMonth = computed(
    () => Month.isCurrent(_month.value),
  );

  /// Falsos nos limites que o backend aceita (2000–2100), para a seta ficar
  /// desabilitada em vez de disparar uma requisição que voltaria 400.
  late final ReadonlySignal<bool> canGoPrevious = computed(
    () => Month.hasPrevious(_month.value),
  );

  late final ReadonlySignal<bool> canGoNext = computed(
    () => Month.hasNext(_month.value),
  );

  @override
  void onInit() async {
    super.onInit();
    await load();
  }

  /// Busca o resumo da competência atual do controller.
  ///
  /// [silent] mantém o conteúdo na tela durante a busca — é o que o
  /// pull-to-refresh quer, já que o `RefreshIndicator` já mostra progresso e
  /// piscar um spinner no lugar da lista seria pior.
  Future<void> load({bool silent = false}) async {
    final requestId = ++_requestId;

    if (!silent) _state.value = const Loading();

    final result = await _repository.getMonthly(month: _month.value);

    // Toque rápido em duas setas dispara duas buscas, e elas podem voltar fora
    // de ordem — sem esta guarda, a resposta do mês antigo sobrescreveria a do
    // mês que está na tela.
    if (requestId != _requestId) return;

    result.when(
      (success) => _state.value = Loaded(success),
      (err) => _state.value = Failed(err),
    );
  }

  Future<void> goToPreviousMonth() async {
    if (!canGoPrevious.value) return;
    _month.value = Month.previous(_month.value);
    await load();
  }

  Future<void> goToNextMonth() async {
    if (!canGoNext.value) return;
    _month.value = Month.next(_month.value);
    await load();
  }

  Future<void> goToCurrentMonth() => goToMonth(Month.current());

  Future<void> goToMonth(String month) async {
    if (!Month.isValid(month)) return;

    // Pedir o mês que já está selecionado só é no-op se o dado dele estiver na
    // tela. Em Loading ou Failed a busca ainda precisa acontecer — senão um
    // "voltar para o mês atual" a partir de uma tela de erro no próprio mês
    // atual não faria nada, e a tela ficaria presa no erro.
    final alreadyLoaded = _state.value is Loaded<MonthlySummaryModel>;
    if (month == _month.value && alreadyLoaded) return;

    _month.value = month;
    await load();
  }

  Future<void> refresh() => load(silent: true);

  /// `BaseController.dispose` só loga — sem este override os signals nunca são
  /// liberados, e o `computed` continua inscrito na fonte. O get_it chama isto
  /// pelo `dispose:` do registro.
  @override
  void dispose() {
    _state.dispose();
    _month.dispose();
    super.dispose();
  }
}
