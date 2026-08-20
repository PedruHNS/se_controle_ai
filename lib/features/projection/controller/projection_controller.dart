import 'package:signals/signals.dart';

import '../../../core/shared/view_state.dart';
import '../../../core/utils/base_controller.dart';
import '../../../core/utils/month.dart';
import '../../../data/models/month_projection_model.dart';
import '../../../data/repositories/summary_repository.dart';

/// Projeção de saldo: para onde o mês a mês caminha, a partir de hoje.
///
/// É a primeira tela que não é cadastro — ela não escreve nada. O
/// `getProjection` existe desde a Fase 0 e nunca teve consumidor; o que a fase
/// acrescenta é a pergunta que ele responde.
class ProjectionController extends BaseController {
  ProjectionController(this._repository);

  final SummaryRepository _repository;

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

  @override
  void onInit() async {
    super.onInit();
    await load();
  }

  Future<void> load({bool silent = false}) async {
    final requestId = ++_requestId;

    if (!silent) _state.value = const Loading();

    final result = await _repository.getProjection(
      // Sempre do mês corrente: projeção é sobre o que vem, e um "de quando"
      // configurável seria uma segunda pergunta na mesma tela.
      from: Month.current(),
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
    _state.dispose();
    _months.dispose();
    super.dispose();
  }
}
