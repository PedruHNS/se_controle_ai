import 'package:reactive_forms/reactive_forms.dart';
import 'package:signals/signals.dart';

import '../../../core/errors/failure.dart';
import '../../../core/utils/base_controller.dart';
import '../../../core/utils/month.dart';
import '../../../data/models/tag_model.dart';
import '../../../data/repositories/income_repository.dart';
import '../../../data/repositories/tag_repository.dart';

/// Cadastro de ganho.
///
/// O [form] é o estado dos campos e das regras — declarado uma vez, aqui, em
/// vez de espalhado entre `TextEditingController` na view e validação no
/// submit. Sobra para o controller o que o formulário não sabe fazer: falar com
/// o repositório e traduzir a recusa do backend de volta para os campos.
///
/// `FormGroup`, `FormControl` e `Validators` não são widgets, então o controller
/// continua testável sem `pumpWidget` — os widgets `Reactive*` ficam na view.
class IncomeFormController extends BaseController {
  IncomeFormController(this._repository, this._tagRepository);

  final IncomeRepository _repository;
  final TagRepository _tagRepository;

  /// Nomes dos campos como constante: eles aparecem na view, na validação e no
  /// `issues[].path` do backend, e um deles escrito errado falharia calado.
  static const description = 'description';
  static const tagId = 'tagId';
  static const amountCents = 'amountCents';
  static const startMonth = 'startMonth';
  static const recurring = 'recurring';

  /// A chave de erro das mensagens que vêm do backend. Os widgets de campo
  /// sabem exibi-la, e ela é limpa sozinha na próxima validação — ou seja,
  /// assim que a pessoa corrige o campo.
  static const backendError = 'backend';

  final form = FormGroup({
    description: FormControl<String>(validators: [Validators.required]),
    // TAG-07: sem `Validators.required` — no ganho a tag é opcional, ao
    // contrário do gasto. Exigir rótulo no cadastro mais comum do app
    // obrigaria a inventar uma tag para lançar salário.
    tagId: FormControl<String>(),
    amountCents: FormControl<int>(
      validators: [Validators.required, Validators.min(1)],
    ),
    startMonth: FormControl<String>(
      value: Month.current(),
      validators: [Validators.required],
    ),
    recurring: FormControl<bool>(value: true, disabled: false),
  });

  final _tags = signal<List<TagModel>>(const []);
  final _saving = signal<bool>(false);
  final _failure = signal<Failure?>(null);

  ReadonlySignal<bool> get saving => _saving;

  /// As tags que o seletor oferece. Vazia até [loadTags] responder — e uma
  /// lista vazia não impede o cadastro, porque a tag é opcional aqui.
  ReadonlySignal<List<TagModel>> get tags => _tags;

  /// A falha que não pertence a nenhum campo — rede, 500, regra de negócio.
  /// Vira snackbar; erro de campo já está embaixo do campo.
  ReadonlySignal<Failure?> get generalFailure => _failure;

  FormControl<T> control<T>(String name) =>
      form.control(name) as FormControl<T>;

  /// Busca as tags do seletor.
  ///
  /// A falha é engolida de propósito: sendo a tag opcional (TAG-07), não poder
  /// escolher rótulo não pode impedir o cadastro do ganho. O seletor fica
  /// vazio, o resto do formulário funciona.
  Future<void> loadTags() async {
    final result = await _tagRepository.list();
    result.when((list) => _tags.value = list, (_) {});
  }

  /// Devolve o `id` criado, ou null se o formulário é inválido ou o backend
  /// recusou. A view usa o retorno para decidir entre fechar a tela e continuar
  /// mostrando o erro.
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
      description: control<String>(description).value!.trim(),
      tagId: control<String>(tagId).value,
      amountCents: control<int>(amountCents).value!,
      startMonth: control<String>(startMonth).value!,
      recurring: control<bool>(recurring).value ?? true,
    );

    _saving.value = false;

    return result.when((id) => id, (failure) {
      _applyFailure(failure);
      return null;
    });
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
        ..setErrors({backendError: issue.message})
        ..markAsTouched();
      placed = true;
    }

    _failure.value = placed ? null : failure;
  }

  @override
  void dispose() {
    form.dispose();
    _saving.dispose();
    _failure.dispose();
    super.dispose();
  }
}
