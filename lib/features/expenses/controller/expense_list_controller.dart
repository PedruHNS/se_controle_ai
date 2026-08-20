import 'package:signals/signals.dart';

import '../../../core/shared/view_state.dart';
import '../../../core/utils/base_controller.dart';
import '../../../data/models/expense_model.dart';
import '../../../data/repositories/expense_repository.dart';

/// Lista de gastos. Mesmo molde do `IncomeListController`: signal privado,
/// getter `ReadonlySignal`, nenhum import de Flutter.
///
/// A listagem é **sem `?month`** pelo mesmo motivo da de ganhos — esta é a tela
/// de cadastro, e esconder um gasto encerrado porque hoje é dezembro deixaria o
/// usuário sem como consultar ou apagar o que cadastrou. A consequência é que o
/// backend devolve `amountCents: null` em todos (GFX-10 ao contrário), e o
/// valor exibido sai do `history` — ver `ExpenseModel.amountCentsIn`.
class ExpenseListController extends BaseController {
  ExpenseListController(this._repository);

  final ExpenseRepository _repository;

  final _state = signal<ViewState<List<ExpenseModel>>>(const Loading());

  /// Cresce a cada requisição. Serve para descartar resposta atrasada — mesmo
  /// contador do `HomeController`.
  int _requestId = 0;

  ReadonlySignal<ViewState<List<ExpenseModel>>> get state => _state;

  @override
  void onInit() async {
    super.onInit();
    await load();
  }

  /// [silent] mantém a lista na tela durante a busca, para o pull-to-refresh
  /// não piscar e para a volta de uma ação não apagar o conteúdo.
  Future<void> load({bool silent = false}) async {
    final requestId = ++_requestId;

    if (!silent) _state.value = const Loading();

    final result = await _repository.list();

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
    _state.dispose();
    super.dispose();
  }
}
