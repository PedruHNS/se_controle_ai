import 'package:reactive_forms/reactive_forms.dart';
import 'package:signals/signals.dart';

import '../../../core/errors/failure.dart';
import '../../../core/shared/patch.dart';
import '../../../core/utils/base_controller.dart';
import '../../../core/utils/month.dart';
import '../../../data/models/credit_card_model.dart';
import '../../../data/models/expense_model.dart';
import '../../../data/repositories/credit_card_repository.dart';
import '../../../data/repositories/expense_repository.dart';

/// Cadastro e edição de gasto fixo, no mesmo formulário.
///
/// **Em edição, só os dados cadastrais aparecem.** Descrição, categoria, forma
/// de pagamento e cartão não são versionados (GFX-06): mudá-los vale para todos
/// os meses, inclusive os passados. Valor, competência inicial e recorrência
/// ficam de fora de propósito — quem mexe em dinheiro é reajuste, correção ou
/// encerramento, na tela de detalhe, e cada um faz uma coisa diferente com o
/// passado (CONC-11). Um campo "valor" aqui apagaria essa escolha.
///
/// O diff do `PATCH` é o mesmo do CAR-08 do cartão: [_expenseOnOpen] é o "antes",
/// e é por ele que "não mexi" se separa de "apaguei" — dois estados que chegam
/// do `FormControl` iguais, como `null`.
class ExpenseFormController extends BaseController {
  ExpenseFormController(this._repository, this._cardRepository);

  final ExpenseRepository _repository;
  final CreditCardRepository _cardRepository;

  /// Nomes dos campos, iguais aos do backend porque é assim que o
  /// `issues[].path` de um 400 encontra o campo certo.
  static const description = 'description';
  static const category = 'category';
  static const paymentMethod = 'paymentMethod';
  static const creditCardId = 'creditCardId';
  static const amountCents = 'amountCents';
  static const startMonth = 'startMonth';
  static const recurring = 'recurring';

  static const backendError = 'backend';

  /// Null em cadastro, preenchido em edição. Vem do [start], não do construtor:
  /// id é dado de rota.
  String? _id;

  /// O gasto como o backend o entregou ao abrir a tela — o "antes" do diff.
  /// **Não** é atualizado enquanto a pessoa digita.
  ExpenseModel? _expenseOnOpen;

  List<CreditCardModel> _cards = const [];

  final form = FormGroup({
    description: FormControl<String>(validators: [Validators.required]),
    category: FormControl<String>(),
    // Débito é o padrão porque é o caso sem pergunta seguinte: escolher cartão
    // obriga a escolher qual.
    paymentMethod: FormControl<PaymentMethod>(value: PaymentMethod.debit),
    creditCardId: FormControl<String>(),
    amountCents: FormControl<int>(
      validators: [Validators.required, Validators.min(1)],
    ),
    startMonth: FormControl<String>(
      value: Month.current(),
      validators: [Validators.required],
    ),
    recurring: FormControl<bool>(value: true),
  });

  final _saving = signal<bool>(false);
  final _ready = signal<bool>(false);
  final _failure = signal<Failure?>(null);

  ReadonlySignal<bool> get saving => _saving;

  /// O formulário pode ser mostrado? Só depois de a lista de cartões chegar —
  /// e, em edição, também o gasto. Preencher os campos depois, por cima do que
  /// a pessoa digitou, seria pior que esperar.
  ReadonlySignal<bool> get ready => _ready;

  /// A falha que não pertence a campo nenhum: rede, 500, o 422 de regra de
  /// negócio, e os `GET` que não voltaram.
  ReadonlySignal<Failure?> get generalFailure => _failure;

  bool get isEditing => _id != null;

  String? get id => _id;

  /// Os cartões que o seletor oferece. Carregados no [start], antes de o
  /// formulário aparecer, então a view lê isto sem precisar de signal.
  List<CreditCardModel> get cards => _cards;

  FormControl<T> control<T>(String name) =>
      form.control(name) as FormControl<T>;

  /// Recebe o id da rota — null para cadastro — e prepara o formulário.
  ///
  /// A lista de cartões é buscada **sempre**, inclusive em gasto no débito: a
  /// forma de pagamento pode ser trocada no meio do preenchimento, e ir buscar
  /// só quando a pessoa marca "cartão" deixaria o seletor vazio por um instante.
  Future<void> start({String? id}) async {
    _id = id;
    _failure.value = null;
    _ready.value = false;

    final cards = await _cardRepository.list();

    final loaded = cards.when(
      (list) {
        _cards = list;
        return true;
      },
      (failure) {
        // Sem cartões não dá para oferecer a escolha, e um formulário que só
        // aceita débito recusaria em silêncio metade dos gastos. A tela mostra o
        // erro com o botão de tentar de novo.
        _failure.value = failure;
        return false;
      },
    );

    if (!loaded) return;

    if (id == null) {
      _syncCreditCardValidators();
      _ready.value = true;
      return;
    }

    final result = await _repository.getById(id);

    result.when((expense) {
      _fill(expense);
      _syncCreditCardValidators();
      _ready.value = true;
    }, (failure) => _failure.value = failure);
  }

  /// Nova tentativa dos `GET` que a tela precisa para abrir.
  Future<void> retry() => start(id: _id);

  /// Troca a forma de pagamento.
  ///
  /// É um método, e não um `valueChanges` escutado: a troca tem dois efeitos que
  /// precisam valer **no mesmo instante** — cartão vira obrigatório, ou é
  /// descartado —, e o stream do reactive_forms entrega no microtask seguinte.
  /// Quem salvasse no mesmo frame da troca veria o estado anterior.
  void selectPaymentMethod(PaymentMethod method) {
    control<PaymentMethod>(paymentMethod).updateValue(method);
    _syncCreditCardValidators();
  }

  /// Cartão é obrigatório quando a forma de pagamento é cartão, e proibido
  /// quando é débito (GFX-01). O backend recusa com 422; validar aqui evita a
  /// viagem e diz o que falta embaixo do campo.
  ///
  /// Trocar para débito **limpa** o cartão escolhido, que é o que o backend faz
  /// do lado dele no `PATCH` (GFX-07) — deixar o valor pendurado num campo
  /// escondido mandaria cartão junto com débito.
  void _syncCreditCardValidators() {
    final card = control<String>(creditCardId);

    if (control<PaymentMethod>(paymentMethod).value == PaymentMethod.debit) {
      card
        ..clearValidators()
        ..updateValue(null)
        ..markAsUntouched();
      return;
    }

    card.setValidators([Validators.required], autoValidate: true);
  }

  void _fill(ExpenseModel expense) {
    _expenseOnOpen = expense;

    form.patchValue({
      description: expense.description,
      category: expense.category,
      paymentMethod: expense.paymentMethod,
      creditCardId: expense.creditCardId,
    });

    // Um gasto vindo do backend é válido por definição, e marcar os campos como
    // intocados evita erro em vermelho antes de a pessoa mexer em nada.
    form.markAsUntouched();
  }

  /// Devolve o id do gasto salvo, ou null quando o formulário é inválido ou o
  /// backend recusou. A view usa o retorno para decidir entre fechar a tela e
  /// continuar mostrando o erro.
  Future<String?> submit() async {
    // De novo aqui, e não só no [selectPaymentMethod]: é esta chamada que faz a
    // guarda do GFX-01 valer mesmo que o campo tenha sido preenchido por outro
    // caminho — `patchValue` em bloco, por exemplo.
    _syncCreditCardValidators();

    // Em edição, valor e competência não estão na tela — e eles nascem
    // inválidos (vazios). Validar o grupo inteiro travaria o salvamento sem ter
    // o que corrigir, então cada modo valida só o que mostra.
    final fields = isEditing
        ? [description, category, paymentMethod, creditCardId]
        : form.controls.keys.toList();

    final invalid = fields
        .map((field) => form.control(field))
        .where((control) => control.invalid);

    if (invalid.isNotEmpty) {
      // Sem isto, um campo nunca tocado fica inválido e silencioso: a pessoa
      // aperta Salvar e nada acontece, sem explicação.
      for (final control in invalid) {
        control.markAsTouched();
      }
      return null;
    }

    _saving.value = true;
    _failure.value = null;

    final id = isEditing ? await _update() : await _create();

    _saving.value = false;

    return id;
  }

  Future<String?> _create() async {
    final result = await _repository.createFixed(
      description: _description,
      category: _category,
      paymentMethod: _method,
      creditCardId: _cardId,
      amountCents: control<int>(amountCents).value!,
      startMonth: control<String>(startMonth).value!,
      recurring: control<bool>(recurring).value ?? true,
    );

    return result.when((id) => id, (failure) {
      _applyFailure(failure);
      return null;
    });
  }

  Future<String?> _update() async {
    final before = _expenseOnOpen!;

    final newCategory = Patch<String>.diff(_category, before.category);
    // Quando a forma vira débito, `_cardId` é null e o diff dá `clear()`. O
    // backend limparia sozinho (GFX-07), mas mandar explícito não custa e
    // deixa o corpo legível no log.
    final newCard = Patch<String>.diff(_cardId, before.creditCardId);

    final newDescription = _description == before.description
        ? null
        : _description;
    final newMethod = _method == before.paymentMethod ? null : _method;

    final nothingChanged =
        newDescription == null &&
        newMethod == null &&
        !newCategory.changesSomething &&
        !newCard.changesSomething;

    // Salvar sem ter mexido em nada seria um `PATCH` de corpo vazio, e o
    // backend responde 400. Prender quem só abriu e fechou seria absurdo, então
    // a tela fecha como se tivesse salvo — porque, em efeito, salvou.
    if (nothingChanged) return _id;

    final result = await _repository.updateDetails(
      _id!,
      description: newDescription,
      paymentMethod: newMethod,
      category: newCategory,
      creditCardId: newCard,
    );

    return result.when((_) => _id, (failure) {
      _applyFailure(failure);
      return null;
    });
  }

  String get _description => control<String>(description).value!.trim();

  /// Categoria vazia é `null`, e não `''`: o backend recusa string de tamanho
  /// zero, e vazio aqui quer dizer "sem categoria".
  String? get _category {
    final value = control<String>(category).value?.trim() ?? '';
    return value.isEmpty ? null : value;
  }

  PaymentMethod get _method => control<PaymentMethod>(paymentMethod).value!;

  /// No débito não vai cartão nenhum, mesmo que um tenha sido escolhido antes
  /// da troca (GFX-01).
  String? get _cardId => _method == PaymentMethod.debit
      ? null
      : control<String>(creditCardId).value;

  /// Um 400 traz `issues[].path` no mesmo nome dos campos, então ele vira erro
  /// de campo. O resto — inclusive o 422 de "gasto no cartão exige informar o
  /// cartão", que não vem com `path` — sobe como falha geral.
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
