import 'package:reactive_forms/reactive_forms.dart';
import 'package:signals/signals.dart';

import '../../../core/errors/failure.dart';
import '../../../core/shared/patch.dart';
import '../../../core/utils/base_controller.dart';
import '../../../data/models/credit_card_model.dart';
import '../../../data/repositories/credit_card_repository.dart';

/// Cadastro e edição de cartão, no mesmo formulário.
///
/// Ganho tem duas telas para mexer em dinheiro (reajuste e correção) porque as
/// duas fazem coisas diferentes com o passado. Cartão não tem passado: os dados
/// dele são configuração, e trocar o dia de fechamento não reescreve mês nenhum.
/// Então uma tela só, e o modo é decidido pelo id que a view entrega no [start].
///
/// **O que esta tela tem de próprio é o CAR-08:** no `PATCH`, campo ausente não
/// muda nada e `null` limpa. O formulário precisa distinguir "não mexi" de
/// "apaguei" — duas coisas que chegam do `FormControl` exatamente iguais, como
/// `null`. Quem as separa é [_cardOnOpen], o cartão como ele estava quando a tela
/// abriu: comparar com ele é a única forma de saber se a pessoa tocou no campo.
class CreditCardFormController extends BaseController {
  CreditCardFormController(this._repository);

  final CreditCardRepository _repository;

  /// Nomes dos campos, iguais aos do backend porque é assim que o `issues[].path`
  /// de um 400 encontra o campo certo.
  static const name = 'name';
  static const lastDigits = 'lastDigits';
  static const closingDay = 'closingDay';
  static const dueDay = 'dueDay';
  static const limitCents = 'limitCents';

  static const backendError = 'backend';

  /// Chave do erro de formato dos quatro dígitos.
  static const fourDigitsError = 'fourDigits';

  /// Null em cadastro, preenchido em edição. Vem do [start], não do construtor:
  /// id é dado de rota.
  String? _id;

  /// O cartão como o backend o entregou ao abrir a tela. É o "antes" do diff do
  /// CAR-08, e por isso **não** é atualizado enquanto a pessoa digita.
  CreditCardModel? _cardOnOpen;

  final form = FormGroup({
    name: FormControl<String>(validators: [Validators.required]),
    // Opcional (CAR-01), mas exatamente quatro dígitos quando vem.
    lastDigits: FormControl<String>(
      validators: [Validators.delegate(_optionalFourDigits)],
    ),
    // Nascem preenchidos: o seletor de dia não tem estado vazio, e um cartão sem
    // dia escolhido não existe. Dia 1 e dia 10 são só um ponto de partida
    // qualquer, perto do começo do mês.
    closingDay: FormControl<int>(value: 1, validators: [Validators.required]),
    dueDay: FormControl<int>(value: 10, validators: [Validators.required]),
    // Opcional e sem mínimo obrigatório — limite zero não faz sentido, mas quem
    // recusa isso é o backend; aqui um `Validators.min` só atrapalharia quem
    // está apagando o campo.
    limitCents: FormControl<int>(),
  });

  final _saving = signal<bool>(false);
  final _ready = signal<bool>(false);
  final _failure = signal<Failure?>(null);

  ReadonlySignal<bool> get saving => _saving;

  /// O formulário pode ser mostrado? Em cadastro é imediato; em edição só depois
  /// de o cartão chegar, senão a pessoa digitaria em cima de campos que o
  /// `GET` vai sobrescrever.
  ReadonlySignal<bool> get ready => _ready;

  /// A falha que não pertence a campo nenhum: rede, 500, o `GET` da edição que
  /// não voltou, e o 400 de corpo vazio, cujo `path` vem `""`.
  ReadonlySignal<Failure?> get generalFailure => _failure;

  bool get isEditing => _id != null;

  String? get id => _id;

  FormControl<T> control<T>(String name) =>
      form.control(name) as FormControl<T>;

  /// Dígitos são opcionais, mas se vierem têm que ser quatro (CAR-01).
  /// `Validators.pattern` sozinho recusaria o campo vazio, que é válido.
  static Map<String, dynamic>? _optionalFourDigits(
    AbstractControl<dynamic> control,
  ) {
    final value = (control.value as String?)?.trim() ?? '';
    if (value.isEmpty) return null;
    return RegExp(r'^\d{4}$').hasMatch(value) ? null : {fourDigitsError: true};
  }

  /// Recebe o id da rota — null para cadastro — e prepara o formulário.
  ///
  /// A view chama isto no `initState`, como no detalhe de ganho.
  Future<void> start({String? id}) async {
    _id = id;

    if (id == null) {
      _ready.value = true;
      return;
    }

    _failure.value = null;

    // Sem `?month`: aqui o `dueDate` não interessa, e pedir competência só para
    // descartar a resposta seria trabalho a mais no backend.
    final result = await _repository.getById(id);

    result.when(
      (card) {
        _fill(card);
        _ready.value = true;
      },
      // Sem `ready`, então a tela mostra o erro em vez de um formulário vazio
      // que salvaria em cima de dados que ninguém viu.
      (failure) => _failure.value = failure,
    );
  }

  /// Nova tentativa do `GET` da edição.
  Future<void> retry() => start(id: _id);

  void _fill(CreditCardModel card) {
    _cardOnOpen = card;

    form.patchValue({
      name: card.name,
      lastDigits: card.lastDigits,
      closingDay: card.closingDay,
      dueDay: card.dueDay,
      limitCents: card.limitCents,
    });

    // Um cartão vindo do backend é válido por definição, e marcar os campos como
    // intocados evita erro em vermelho antes de a pessoa mexer em nada.
    form.markAsUntouched();
  }

  /// Devolve o id do cartão salvo, ou null quando o formulário é inválido ou o
  /// backend recusou. A view usa o retorno para decidir entre fechar a tela e
  /// continuar mostrando o erro.
  Future<String?> submit() async {
    if (form.invalid) {
      form.markAllAsTouched();
      return null;
    }

    _saving.value = true;
    _failure.value = null;

    final id = isEditing ? await _update() : await _create();

    _saving.value = false;

    return id;
  }

  /// Devolve o id criado, ou null quando o backend recusou — nesse caso o erro
  /// já está no campo ou no signal de falha geral.
  Future<String?> _create() async {
    final result = await _repository.create(
      name: _name,
      closingDay: control<int>(closingDay).value!,
      dueDay: control<int>(dueDay).value!,
      lastDigits: _lastDigits,
      limitCents: control<int>(limitCents).value,
    );

    return result.when((id) => id, (failure) {
      _applyFailure(failure);
      return null;
    });
  }

  /// Devolve o id do cartão editado, ou null quando o backend recusou.
  Future<String?> _update() async {
    final before = _cardOnOpen!;

    // Cada campo entra no `PATCH` só se mudou. É o CAR-08 lido do lado do
    // cliente: mandar o valor igual ao que já está lá funcionaria, mas apagaria
    // a diferença entre "não mexi" e "reenviei igual" na primeira vez que o
    // backend passasse a tratar as duas coisas diferente.
    final digits = Patch<String>.diff(_lastDigits, before.lastDigits);
    final limit = Patch<int>.diff(
      control<int>(limitCents).value,
      before.limitCents,
    );

    final newName = _name == before.name ? null : _name;
    final newClosingDay = control<int>(closingDay).value == before.closingDay
        ? null
        : control<int>(closingDay).value;
    final newDueDay = control<int>(dueDay).value == before.dueDay
        ? null
        : control<int>(dueDay).value;

    final nothingChanged =
        newName == null &&
        newClosingDay == null &&
        newDueDay == null &&
        !digits.changesSomething &&
        !limit.changesSomething;

    // Salvar sem ter mexido em nada é um `PATCH` de corpo vazio, e o backend
    // responde 400 "Informe ao menos um campo para atualizar". Recusar a saída
    // por causa disso seria absurdo para quem só abriu e fechou, então a tela
    // fecha como se tivesse salvo — porque, em efeito, salvou.
    if (nothingChanged) return _id;

    final result = await _repository.update(
      _id!,
      name: newName,
      closingDay: newClosingDay,
      dueDay: newDueDay,
      lastDigits: digits,
      limitCents: limit,
    );

    return result.when((_) => _id, (failure) {
      _applyFailure(failure);
      return null;
    });
  }

  String get _name => control<String>(name).value!.trim();

  /// Campo de dígitos vazio é `null`, e não `''`: o backend recusa string de
  /// tamanho zero, e vazio aqui quer dizer "sem dígitos".
  String? get _lastDigits {
    final value = control<String>(lastDigits).value?.trim() ?? '';
    return value.isEmpty ? null : value;
  }

  /// Mesmo tratamento do formulário de ganho: `issues[].path` que corresponde a
  /// um campo vira erro do campo; o resto sobe como falha geral.
  ///
  /// O 400 de corpo vazio chega com `path` `""`, que não é campo nenhum — cai no
  /// caminho geral, como deve. Na prática ele não deveria acontecer, porque
  /// [_update] não manda requisição quando nada mudou.
  void _applyFailure(Failure failure) {
    if (failure is! ValidationFailure || failure.issues.isEmpty) {
      _failure.value = failure;
      return;
    }

    var placed = false;
    for (final issue in failure.issues) {
      if (issue.path.isEmpty || !form.contains(issue.path)) continue;
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
    _ready.dispose();
    _failure.dispose();
    super.dispose();
  }
}
