import 'package:signals/signals.dart';

import '../../../core/errors/failure.dart';
import '../../../core/shared/patch.dart';
import '../../../core/shared/view_state.dart';
import '../../../core/utils/base_controller.dart';
import '../../../data/models/tag_model.dart';
import '../../../data/repositories/tag_repository.dart';

/// Lista de tags, com criação, edição e exclusão a partir dela.
///
/// Não há tela de detalhe nem formulário de página inteira: a tag tem dois
/// campos, e uma tela cheia para nome e cor seria navegação sem conteúdo. Tudo
/// acontece em diálogo, sobre a lista.
///
/// Diferente das outras listas, aqui não há competência: tag não é versionada
/// (TAG-03), então não existe "as tags de agosto" — renomear muda o rótulo em
/// todo o histórico, e isso é intencional.
class TagListController extends BaseController {
  TagListController(this._repository);

  final TagRepository _repository;

  final _state = signal<ViewState<List<TagModel>>>(const Loading());
  final _working = signal<bool>(false);

  ReadonlySignal<ViewState<List<TagModel>>> get state => _state;

  /// Gravação em andamento. A view desabilita os botões para não pedir duas
  /// vezes — criar a mesma tag duas vezes daria 409 na segunda (TAG-01), o que
  /// seria um erro confuso de um clique acidental.
  ReadonlySignal<bool> get working => _working;

  @override
  void onInit() async {
    super.onInit();
    await _load();
  }

  Future<void> _load() async {
    _state.value = const Loading();

    final result = await _repository.list(includeArchived: false);

    result.when(
      (success) => _state.value = Loaded(success),
      (err) => _state.value = Failed(err),
    );
  }

  Future<void> refresh() => _load();

  /// Devolve a falha para quem chamou em vez de guardá-la em signal, como as
  /// outras listas fazem: o 409 de nome repetido (TAG-01) pertence ao diálogo,
  /// que continua aberto com o texto digitado, e não à lista, que está correta.
  Future<Failure?> create({required String name, String? color}) async {
    _working.value = true;

    final result = await _repository.create(name: name, color: color);

    return result.when((_) async {
      await _load();
      return null;
    }, (error) async => error);
  }

  /// [color] é [Patch] e não `String?` pelo motivo do CAR-08: ausente não mexe,
  /// `null` limpa. Sem isso, tirar a cor de uma tag seria indistinguível de não
  /// ter tocado nela.
  Future<Failure?> update(
    String id, {
    String? name,
    Patch<String> color = const Patch.keep(),
  }) async {
    _working.value = true;

    final result = await _repository.update(id, name: name, color: color);

    _working.value = false;

    return result.when((_) async {
      await _load();
      return null;
    }, (error) async => error);
  }

  /// Dois desfechos (TAG-08): sem uso apaga, em uso arquiva. Devolve o que
  /// aconteceu junto com a falha, para a tela dizer a frase certa — "excluída"
  /// e "arquivada" não são a mesma notícia.
  Future<({Failure? failure, bool archived})> delete(String id) async {
    _working.value = true;

    final result = await _repository.delete(id);

    _working.value = false;

    return result.when((outcome) async {
      await _load();
      return (failure: null, archived: outcome.archived);
    }, (error) async => (failure: error, archived: false));
  }

  /// Traz a arquivada de volta para as escolhas de lançamento novo.
  Future<Failure?> restore(String id) async {
    _working.value = true;

    final result = await _repository.restore(id);

    _working.value = false;

    return result.when((_) async {
      await _load();
      return null;
    }, (error) async => error);
  }

  @override
  void dispose() {
    _state.dispose();
    _working.dispose();
    super.dispose();
  }
}
