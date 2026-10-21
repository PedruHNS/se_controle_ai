import 'package:reactive_forms/reactive_forms.dart';
import 'package:se_controle_ai/core/shared/mixin/message_mixin.dart';
import 'package:se_controle_ai/data/services/navigation_service.dart';
import 'package:signals/signals.dart';
import '../../../core/shared/view_state.dart';
import '../../../core/utils/base_controller.dart';
import '../../../data/models/tag_model.dart';
import '../../../data/repositories/tag_repository.dart';

class TagListController extends BaseController with MessageMixin {
  final TagRepository _repository;
  final NavigationService _nav;
  TagListController({required this._repository, required this._nav});

  final _state = signal<ViewState<List<TagModel>>>(const Loading());
  ReadonlySignal<ViewState<List<TagModel>>> get state => _state;

  final _colorSelected = signal<String?>(null);
  ReadonlySignal<String?> get getColorSelected => _colorSelected;
  set setColorSelected(String? hex) => _colorSelected.value = hex;

  final form = FormGroup({
    'title': FormControl<String>(
      validators: [Validators.maxLength(200), Validators.required],
    ),
  });

  @override
  void onInit() async {
    super.onInit();
    await _load();
  }

  @override
  void dispose() {
    super.dispose();
    _state.dispose();
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

  void clearText() {
    form.control('title').reset();
    _colorSelected.value = null;
  }

  void loadTag(TagModel tag) {
    form.control('title').updateValue(tag.name);
    _colorSelected.value = tag.color;
  }

  Future<void> refresh() => _load();

  Future<void> create() async {
    final color = _colorSelected.value;
    if (color == null) return toastError('Escolha uma cor para a tag.');

    final result = await _repository.create(
      name: form.control('title').value,
      color: color,
    );

    result.when(
      (tag) {
        final current = _state.value;
        if (current is Loaded<List<TagModel>>) {
          final newList = [...current.data, tag]
            ..sort((a, b) => a.name.compareTo(b.name));

          _state.value = Loaded(newList);
        }

        _nav.pop<TagModel>(tag);
        Future.delayed(
          Duration(milliseconds: 300),
          () => toastSucess('tag adicionada com sucesso.'),
        );
      },
      (err) {
        _nav.pop();
        Future.delayed(
          Duration(milliseconds: 300),
          () => toastError(err.message),
        );
      },
    );
  }

  Future<void> update(String id) async {
    final current = _state.value;
    if (current is! Loaded<List<TagModel>>) return;

    final color = _colorSelected.value;
    if (color == null) return toastError('Escolha uma cor para a tag.');

    final result = await _repository.update(
      id,
      name: form.control('title').value,
      color: color,
    );

    result.when(
      (tag) {
        final index = current.data.indexWhere((item) => item.id == tag.id);
        if (index == -1) return;

        final newList = [...current.data];
        newList[index] = tag;
        newList.sort((a, b) => a.name.compareTo(b.name));

        _state.value = Loaded(newList);
      },
      (err) => Future.delayed(
        Duration(milliseconds: 300),
        () => toastError(err.message),
      ),
    );
    _nav.pop();
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
