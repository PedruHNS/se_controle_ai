import 'package:signals/signals.dart';

import '../../../core/month/selected_month_controller.dart';
import '../../../core/shared/view_state.dart';
import '../../../core/utils/base_controller.dart';
import '../../../data/models/month_projection_model.dart';
import '../../../data/repositories/summary_repository.dart';

/// Projeção de saldo: para onde o mês a mês caminha, a partir de hoje.
///
/// É a primeira tela que não é cadastro — ela não escreve nada. O
/// `getProjection` existe desde a Fase 0 e nunca teve consumidor; o que a fase
/// acrescenta é a pergunta que ele responde.
class ProjectionController extends BaseController {
  ProjectionController(this._repository, this._selectedMonth);

  final SummaryRepository _repository;
  final SelectedMonthController _selectedMonth;

  /// Desfaz a inscrição no mês — ver [onInit].
  EffectCleanup? _watchingMonth;

  /// Os horizontes que a tela oferece. O backend aceita de 1 a 60 meses; estes
  /// três são os que respondem perguntas diferentes — o semestre, o ano, e "e
  /// depois?".
  static const horizons = [6, 12, 24];

  final _state = signal<ViewState<List<MonthProjectionModel>>>(const Loading());
  final _months = signal<int>(12);

  /// Cresce a cada requisição, para descartar resposta atrasada. Aqui ele pesa
  /// mais que nas outras telas: trocar o horizonte duas vezes seguidas é um
  /// toque rápido, e a resposta de 24 meses pode chegar depois da de 6.
  int _requestId = 0;

  ReadonlySignal<ViewState<List<MonthProjectionModel>>> get state => _state;

  /// Quantos meses a projeção cobre.
  ReadonlySignal<int> get months => _months;

  /// A inscrição no mês **é** a carga inicial: o `effect` roda uma vez ao ser
  /// criado, e de novo a cada troca de mês na home.
  @override
  void onInit() {
    super.onInit();

    _watchingMonth = effect(() {
      _selectedMonth.month.value;
      // `untracked` porque o `load` lê o horizonte: sem isto, trocar de 6 para
      // 12 meses dispararia o efeito **e** a busca do próprio `setMonths`, duas
      // requisições para um toque.
      untracked(load);
    });
  }

  Future<void> load({bool silent = false}) async {
    final requestId = ++_requestId;

    if (!silent) _state.value = const Loading();

    final result = await _repository.getProjection(
      // Do mês selecionado, e não do corrente: a projeção responde "a partir
      // daqui, para onde isto caminha", e o "aqui" é o mês que a pessoa
      // escolheu na home. Um seletor próprio nesta tela seria a mesma pergunta
      // feita duas vezes.
      from: _selectedMonth.month.value,
      months: _months.value,
    );

    if (requestId != _requestId) return;

    result.when(
      (success) => _state.value = Loaded(success),
      (err) => _state.value = Failed(err),
    );
  }

  /// Troca o horizonte e busca de novo. Repetir o horizonte atual não gera
  /// requisição — o `SegmentedButton` avisa mesmo quando a escolha não muda.
  Future<void> setMonths(int value) async {
    if (value == _months.value) return;
    _months.value = value;
    // Silencioso: o gráfico some por um instante e volta com outro tamanho, e
    // um spinner no lugar dele faria a tela piscar a cada toque.
    await load(silent: true);
  }

  Future<void> refresh() => load(silent: true);

  @override
  void dispose() {
    _watchingMonth?.call();
    _state.dispose();
    _months.dispose();
    super.dispose();
  }
}
