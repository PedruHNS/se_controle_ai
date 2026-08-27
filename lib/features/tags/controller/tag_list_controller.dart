import 'package:reactive_forms/reactive_forms.dart';
import 'package:se_controle_ai/core/shared/mixin/message_mixin.dart';
import 'package:se_controle_ai/data/services/navigation_service.dart';
import 'package:signals/signals.dart';

import '../../../core/shared/patch.dart';
import '../../../core/shared/view_state.dart';
import '../../../core/utils/base_controller.dart';
import '../../../core/utils/text_order.dart';
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
class TagListController extends BaseController with MessageMixin {
  final TagRepository _repository;
  final NavigationService _nav;
  TagListController({required this._repository, required this._nav});

  final _state = signal<ViewState<List<TagModel>>>(const Loading());
  final _working = signal<bool>(false);

  final _colorSelected = signal<String?>(null);
  set setColorSelected(String hex) => _colorSelected.value = hex;
  ReadonlySignal<String?> get getColorSelected => _colorSelected;

  final form = FormGroup({
    'title': FormControl<String>(
      validators: [Validators.maxLength(200), Validators.required],
    ),
  });

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

  @override
  void dispose() {
    super.dispose();
    _state.dispose();
    _working.dispose();
    _colorSelected.dispose();
    form.dispose();
  }

  Future<void> _load() async {
    _state.value = const Loading();

    final result = await _repository.list();

    result.when(
      (success) => _state.value = Loaded(success),
      (err) => _state.value = Failed(err),
    );
  }

  /// Devolve o formulário ao estado de "nova tag" — nome e cor.
  ///
  /// A cor entra aqui junto com o nome porque as duas são o mesmo formulário:
  /// limpar só o texto deixava o diálogo reabrir com a cor da tag anterior
  /// marcada, e quem não repara confirma com uma cor que não escolheu.
  void clearText() {
    form.control('title').reset();
    _colorSelected.value = null;
  }

  Future<void> refresh() => _load();

  Future<void> create() async {
    final current = _state.value;
    if (current is! Loaded<List<TagModel>>) return;

    final result = await _repository.create(
      name: form.control('title').value,
      color: _colorSelected.value,
    );

    result.when(
      (tag) {
        final newList = [...current.data, tag]
          ..sort((a, b) => TextOrder.alfabetica(a.name, b.name));

        _state.value = Loaded(newList);
        Future.delayed(
          Duration(milliseconds: 300),
          () => toastSucess('tag adicionada com sucesso.'),
        );
      },
      (err) => Future.delayed(
        Duration(milliseconds: 300),
        () => toastError(err.message),
      ),
    );
    _nav.pop();
  }

  /// Edita por substituição e sem recarregar: o `POST` devolve a tag pronta e
  /// ela troca a linha da lista. Nome e cor vão sempre os dois, e a tag passa a
  /// ser o que foi mandado. `color` nulo é "sem cor" — não existe "não mexe", então
  /// quem só renomeia manda a cor atual junto.
  ///
  /// Vale só para tag. Gasto e cartão continuam com [Patch] e `PATCH`, porque
  /// lá os formulários editam um punhado de campos por vez e mandar o resto de
  /// volta significaria reenviar dinheiro que ninguém tocou.
  Future<void> update(String id, {required String name, String? color}) async {
    final current = _state.value;
    if (current is! Loaded<List<TagModel>>) return;
    final result = await _repository.update(id, name: name, color: color);

    result.when((tag) {
      // A resposta traz a tag pronta, então a linha é trocada aqui mesmo, sem
      // um novo GET.
      //
      // A cópia não é zelo: o `signal` compara por referência, e mexer na lista
      // que está dentro do estado o deixaria com o mesmo objeto — nada seria
      // notificado e a tela seguiria com o nome antigo.
      final atualizadas = [...current.data];
      final posicao = atualizadas.indexWhere((item) => item.id == tag.id);

      if (posicao == -1) return;

      atualizadas[posicao] = tag;
      // Renomear muda o lugar na lista: sem reordenar, "Zebra" ficaria onde
      // "Moradia" estava.
      atualizadas.sort((a, b) => TextOrder.alfabetica(a.name, b.name));

      _state.value = Loaded(atualizadas);
    }, (error) => error);
  }

  Future<void> delete(TagModel tag) async {
    final current = _state.value;
    if (current is! Loaded<List<TagModel>>) return;

    final result = await _repository.delete(tag.id);

    result.when(
      (outcome) {
        _state.value = Loaded(
          current.data.where((item) => item.id != tag.id).toList(),
        );

        Future.delayed(
          Duration(milliseconds: 300),
          () => toastSucess(
            outcome.archived
                ? '${tag.name} foi arquivada e continua nos lançamentos antigos.'
                : '${tag.name} foi excluída.',
          ),
        );
      },
      (err) => Future.delayed(
        Duration(milliseconds: 300),
        () => toastError(err.message),
      ),
    );
    _nav.pop();
  }
}
