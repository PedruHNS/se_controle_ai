import 'package:reactive_forms/reactive_forms.dart';
import 'package:signals/signals.dart';

import '../../../core/errors/failure.dart';
import '../../../core/shared/view_state.dart';
import '../../../core/utils/amount_version_utils.dart';
import '../../../core/utils/base_controller.dart';
import '../../../core/utils/text_order_utils.dart';
import '../../../data/models/income_model.dart';
import '../../../data/models/tag_model.dart';
import '../../../data/repositories/income_repository.dart';
import '../../../data/repositories/tag_repository.dart';
import '../../../data/services/selected_month_service.dart';

class IncomeController extends BaseController {
  final IncomeRepository _repository;
  final TagRepository _tagRepository;
  final SelectedMonthService _selectedMonth;

  IncomeController({
    required this._repository,
    required this._tagRepository,
    required this._selectedMonth,
  });

  // `late` porque o padrão de competência vem de [_selectedMonth]: inicializador
  // de campo não enxerga `this`.
  late final form = FormGroup({
    'description': FormControl<String>(validators: [Validators.required]),
    'tagId': FormControl<String>(),
    'amountCents': FormControl<int>(
      validators: [Validators.required, Validators.min(1)],
    ),

    'startMonth': FormControl<String>(
      value: _selectedMonth.month.value,
      validators: [Validators.required],
    ),

    'recurring': FormControl<bool>(value: false, disabled: false),
  });

  final _state = signal<ViewState<List<IncomeModel>>>(const Loading());
  ReadonlySignal<ViewState<List<IncomeModel>>> get state => _state;

  final _tags = signal<List<TagModel>>(const []);
  ReadonlySignal<List<TagModel>> get tags => _tags;
  final _saving = signal<bool>(false);
  ReadonlySignal<bool> get saving => _saving;
  final _failure = signal<Failure?>(null);
  ReadonlySignal<Failure?> get generalFailure => _failure;

  EffectCleanup? _watchingMonth;

  @override
  void onInit() {
    super.onInit();

    _watchingMonth = effect(() {
      _selectedMonth.month.value;
      untracked(_load);
    });
  }

  @override
  void dispose() {
    _watchingMonth?.call();
    super.dispose();
    _state.dispose();
    form.dispose();
    _tags.dispose();
    _saving.dispose();
    _failure.dispose();
  }

  /// Só o que vige no mês selecionado, com o valor daquele mês (GAN-10).
  Future<void> _load() async {
    final month = _selectedMonth.month.value;
    _state.value = const Loading();
    final result = await _repository.list(month: month);

    // Trocar de mês rápido deixa buscas antigas no caminho: a que chega por
    // último não pode sobrescrever a lista do mês que está na tela.
    if (month != _selectedMonth.month.value) return;

    result.when(
      (success) => _state.value = Loaded(success),
      (err) => _state.value = Failed(err),
    );
  }

  Future<void> refresh() async => await _load();

  FormControl<T> control<T>(String name) =>
      form.control(name) as FormControl<T>;

  /// Deixa o formulário pronto para um cadastro novo e busca as tags do
  /// seletor. A página chama ao abrir.
  ///
  /// Sem await e sem estado de carregamento: a tag é opcional (TAG-07), então o
  /// formulário já é utilizável enquanto a lista não chega — o seletor aparece
  /// vazio e se preenche sozinho.
  ///
  /// O `reset` sem valores devolveria tudo a `null`, inclusive a competência e
  /// o switch, que têm padrão — por isso eles vão escritos aqui.
  Future<void> startForm() async {
    form.reset(
      value: {
        'description': null,
        'tagId': null,
        'amountCents': null,
        'startMonth': _selectedMonth.month.value,
        'recurring': false,
      },
    );
    _saving.value = false;
    _failure.value = null;

    await _loadTags();
  }

  /// A falha é engolida de propósito: sendo a tag opcional (TAG-07), não poder
  /// escolher rótulo não pode impedir o cadastro do ganho. O seletor fica
  /// vazio, o resto do formulário funciona.
  Future<void> _loadTags() async {
    final result = await _tagRepository.list();

    // A página libera o controller ao sair, e a lista pode chegar depois.
    // Escrever num signal liberado lança.
    if (_tags.disposed) return;

    result.when((list) => _tags.value = list, (_) {});
  }

  /// Devolve o `id` criado, ou null se o formulário é inválido ou o backend
  /// recusou. A view usa o retorno para decidir entre fechar a tela e continuar
  /// mostrando o erro.
  ///
  /// [saving] só desliga depois de o ganho entrar na lista, e não quando o
  /// backend responde: a busca do ganho criado leva um instante, e o botão
  /// liberado nesse intervalo deixaria cadastrar duas vezes.
  Future<String?> submit() async {
    if (form.invalid) {
      // Sem isto, um campo nunca tocado fica inválido e silencioso: a pessoa
      // aperta Salvar e nada acontece, sem explicação.
      form.markAllAsTouched();
      return null;
    }

    _saving.value = true;
    _failure.value = null;

    final result = await _repository.create(
      description: control<String>('description').value!.trim(),
      tagId: control<String>('tagId').value,
      amountCents: control<int>('amountCents').value!,
      startMonth: control<String>('startMonth').value!,
      recurring: control<bool>('recurring').value ?? false,
    );

    return result.when(
      (id) async {
        await _addCreated(id);
        _saving.value = false;
        return id;
      },
      (failure) async {
        _saving.value = false;
        _applyFailure(failure);
        return null;
      },
    );
  }

  /// Põe na lista o ganho que acabou de ser criado, sem buscar a lista inteira.
  ///
  /// O `201` traz só o `id`, e o ganho que entra na lista precisa estar inteiro:
  /// `endMonth` e `history` dependem de `recurring`, e quem sabe essa conta é o
  /// backend (GAN-02). Por isso busca o ganho criado, em vez de montá-lo aqui.
  ///
  /// Lista que não está na tela (carregando, ou em falha) não tem o que
  /// reescrever, e falha na busca do ganho deixa a lista sem ele — nos dois
  /// casos busca tudo de novo. O ganho já foi criado, então nada disso vira
  /// erro do cadastro.
  ///
  /// Ganho que não vige no mês exibido não entra: a lista é a daquele mês.
  Future<void> _addCreated(String id) async {
    final month = _selectedMonth.month.value;
    final created = await _repository.getById(id, month: month);
    final current = _state.value;

    if (current is! Loaded<List<IncomeModel>> || created.isError()) {
      await _load();
      return;
    }

    final income = created.tryGetSuccess()!;
    if (AmountVersionUtils.amountCentsIn(income.history, month) == null) return;

    _state.value = Loaded([...current.data, income]..sort(_byDescription));
  }

  /// A ordem em que o backend lista (`ORDER BY description, valid_from`), para o
  /// ganho novo cair onde a próxima busca o poria.
  int _byDescription(IncomeModel a, IncomeModel b) {
    final byName = TextOrderUtils.alfabetica(a.description, b.description);
    return byName != 0 ? byName : a.startMonth.compareTo(b.startMonth);
  }

  /// Um 400 traz `issues[].path` no mesmo nome dos campos, então ele vira erro
  /// de campo. O resto — e um 400 cujo `path` não corresponde a campo nenhum —
  /// sobe como falha geral, senão a pessoa veria a tela recusar sem dizer nada.
  void _applyFailure(Failure failure) {
    if (failure is! ValidationFailure || failure.issues.isEmpty) {
      _failure.value = failure;
      return;
    }

    var placed = false;
    for (final issue in failure.issues) {
      if (!form.contains(issue.path)) continue;
      form.control(issue.path)
        ..setErrors({'backend': issue.message})
        ..markAsTouched();
      placed = true;
    }

    _failure.value = placed ? null : failure;
  }
}
