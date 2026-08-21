import 'package:reactive_forms/reactive_forms.dart';
import 'package:signals/signals.dart';

import '../../../core/errors/failure.dart';
import '../../../core/shared/patch.dart';
import '../../../core/utils/base_controller.dart';
import '../../../core/utils/month.dart';
import '../../../data/models/credit_card_model.dart';
import '../../../data/models/expense_model.dart';
import '../../../data/models/tag_model.dart';
import '../../../data/repositories/credit_card_repository.dart';
import '../../../data/repositories/expense_repository.dart';
import '../../../data/repositories/tag_repository.dart';

/// Cadastro e edição de gasto, no mesmo formulário.
///
/// **O tipo é escolhido no cadastro e nunca mais muda.** Fixo e parcelado têm
/// regimes de escrita diferentes — vigência de um lado, parcela do outro
/// (GFX-09) — e trocar o tipo de um gasto existente seria jogar fora a fonte da
/// verdade dele. O backend nem oferece a operação; aqui o seletor some na
/// edição.
///
/// **Em edição, só os dados cadastrais aparecem.** Descrição, tag, observação,
/// forma de pagamento e cartão não são versionados (GFX-06): mudá-los vale para todos
/// os meses, inclusive os passados. Valor, competência inicial e recorrência
/// ficam de fora de propósito — quem mexe em dinheiro é reajuste, correção ou
/// encerramento, na tela de detalhe, e cada um faz uma coisa diferente com o
/// passado (CONC-11). Um campo "valor" aqui apagaria essa escolha.
///
/// O diff do `PATCH` é o mesmo do CAR-08 do cartão: [_expenseOnOpen] é o "antes",
/// e é por ele que "não mexi" se separa de "apaguei" — dois estados que chegam
/// do `FormControl` iguais, como `null`.
class ExpenseFormController extends BaseController {
  ExpenseFormController(
    this._repository,
    this._cardRepository,
    this._tagRepository,
  );

  final ExpenseRepository _repository;
  final CreditCardRepository _cardRepository;
  final TagRepository _tagRepository;

  /// Nomes dos campos, iguais aos do backend porque é assim que o
  /// `issues[].path` de um 400 encontra o campo certo.
  static const description = 'description';
  static const tagId = 'tagId';
  static const notes = 'notes';
  static const paymentMethod = 'paymentMethod';
  static const creditCardId = 'creditCardId';
  static const type = 'type';

  // Só no gasto fixo.
  static const amountCents = 'amountCents';
  static const startMonth = 'startMonth';
  static const recurring = 'recurring';

  // Só no parcelado. Os nomes são os do backend, e `firstMonth` não é o mesmo
  // campo que `startMonth`: um `issues[].path` de 400 precisa achar o controle
  // certo, e os dois convivem no mesmo `FormGroup`.
  static const totalCents = 'totalCents';
  static const installmentsCount = 'installmentsCount';
  static const firstMonth = 'firstMonth';

  /// Mínimo do backend (GPR-01): para 1x existe o fixo não recorrente.
  static const minInstallments = 2;
  static const maxInstallments = 120;

  static const backendError = 'backend';

  /// Null em cadastro, preenchido em edição. Vem do [start], não do construtor:
  /// id é dado de rota.
  String? _id;

  /// O gasto como o backend o entregou ao abrir a tela — o "antes" do diff.
  /// **Não** é atualizado enquanto a pessoa digita.
  ExpenseModel? _expenseOnOpen;

  List<CreditCardModel> _cards = const [];
  List<TagModel> _tags = const [];

  final form = FormGroup({
    description: FormControl<String>(validators: [Validators.required]),
    // TAG-06: obrigatória. Era `category`, texto livre e opcional.
    tagId: FormControl<String>(validators: [Validators.required]),
    notes: FormControl<String>(),
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
    type: FormControl<ExpenseType>(value: ExpenseType.fixed),
    totalCents: FormControl<int>(
      validators: [Validators.required, Validators.min(1)],
    ),
    installmentsCount: FormControl<int>(
      value: minInstallments,
      validators: [
        Validators.required,
        Validators.min(minInstallments),
        Validators.max(maxInstallments),
      ],
    ),
    firstMonth: FormControl<String>(
      value: Month.current(),
      validators: [Validators.required],
    ),
  });

  final _tagsSignal = signal<List<TagModel>>(const []);
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

  ExpenseType get selectedType =>
      control<ExpenseType>(type).value ?? ExpenseType.fixed;

  String? get id => _id;

  /// Os cartões que o seletor oferece. Carregados no [start], antes de o
  /// formulário aparecer, então a view lê isto sem precisar de signal.
  List<CreditCardModel> get cards => _cards;

  /// As tags que o seletor oferece, na ordem que o backend devolve (por nome).
  /// Muda quando [createTag] adiciona uma, por isso é signal e não getter puro.
  ReadonlySignal<List<TagModel>> get tags => _tagsSignal;

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

    // Em paralelo: os dois são obrigatórios para a tela abrir, e sequenciar
    // pagaria duas idas ao servidor uma depois da outra sem motivo.
    final (cards, tagList) = await (
      _cardRepository.list(),
      _tagRepository.list(),
    ).wait;

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

    // Sem tags o formulário não tem como salvar (TAG-06), então falhar aqui é
    // tão bloqueante quanto falhar nos cartões.
    final tagsLoaded = tagList.when(
      (list) {
        _setTags(list);
        return true;
      },
      (failure) {
        _failure.value = failure;
        return false;
      },
    );

    if (!tagsLoaded) return;

    if (id == null) {
      _syncCreditCardValidators();
      _ready.value = true;
      return;
    }

    final result = await _repository.getById(id);

    result.when((expense) {
      // O seletor traz só as ativas, mas o gasto em edição pode apontar para
      // uma arquivada depois de ele ter sido criado. Sem ela na lista, o
      // dropdown teria um valor sem item correspondente — que é assertion no
      // Flutter, não um campo vazio. Entra só nesse caso, e some assim que a
      // pessoa escolher outra.
      if (!_tags.any((tag) => tag.id == expense.tag.id)) {
        _setTags([..._tags, expense.tag]..sort((a, b) => a.name.compareTo(b.name)));
      }

      _fill(expense);
      _syncCreditCardValidators();
      _ready.value = true;
    }, (failure) => _failure.value = failure);
  }

  void _setTags(List<TagModel> list) {
    _tags = list;
    _tagsSignal.value = list;
  }

  /// Nova tentativa dos `GET` que a tela precisa para abrir.
  Future<void> retry() => start(id: _id);

  /// Cria uma tag e já a seleciona no formulário.
  ///
  /// Existe aqui, e não só numa tela de gerenciamento, porque a tag substituiu
  /// um campo de texto livre: sem poder criar no meio do cadastro, quem
  /// precisasse de um rótulo novo teria que abandonar o gasto pela metade —
  /// que é pior do que era antes.
  ///
  /// Devolve a mensagem de erro quando o backend recusa (nome repetido é 409,
  /// TAG-01) e `null` quando deu certo. A falha não vai para [generalFailure]:
  /// ela pertence ao diálogo, não à tela inteira, que continua utilizável.
  Future<String?> createTag({required String name, String? color}) async {
    final created = await _tagRepository.create(name: name, color: color);

    return created.when(
      (id) async {
        final refreshed = await _tagRepository.list();

        return refreshed.when(
          (list) {
            _setTags(list);
            control<String>(tagId).updateValue(id);
            return null;
          },
          // A tag existe no servidor, mas a lista local não sabe. Reabrir
          // resolve; travar o formulário por isso seria desproporcional.
          (failure) => failure.message,
        );
      },
      (failure) => failure.message,
    );
  }

  /// A tag escolhida, ou null enquanto nenhuma foi. A view usa para pintar o
  /// chip com a cor certa.
  TagModel? get selectedTag {
    final id = control<String>(tagId).value;
    if (id == null) return null;
    for (final tag in _tags) {
      if (tag.id == id) return tag;
    }
    return null;
  }

  /// Troca entre gasto fixo e parcelado. Só existe no cadastro.
  void selectType(ExpenseType value) =>
      control<ExpenseType>(type).updateValue(value);

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
      tagId: expense.tag.id,
      notes: expense.notes,
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

    // Cada modo valida só o que mostra, e nunca é o grupo inteiro: os campos do
    // outro tipo nascem inválidos por estarem vazios, e em edição valor e
    // competência nem aparecem. Validar tudo travaria o salvamento sem ter o
    // que corrigir na tela.
    final fields = [
      description,
      tagId,
      notes,
      paymentMethod,
      creditCardId,
      if (!isEditing)
        ...switch (selectedType) {
          ExpenseType.fixed => [amountCents, startMonth, recurring],
          ExpenseType.installment => [
            totalCents,
            installmentsCount,
            firstMonth,
          ],
        },
    ];

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

    final id = isEditing
        ? await _update()
        : selectedType == ExpenseType.installment
        ? await _createInstallment()
        : await _createFixed();

    _saving.value = false;

    return id;
  }

  Future<String?> _createFixed() async {
    final result = await _repository.createFixed(
      description: _description,
      tagId: _tagId,
      notes: _notes,
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

  Future<String?> _createInstallment() async {
    final result = await _repository.createInstallment(
      description: _description,
      tagId: _tagId,
      notes: _notes,
      paymentMethod: _method,
      creditCardId: _cardId,
      totalCents: control<int>(totalCents).value!,
      installmentsCount: control<int>(installmentsCount).value!,
      firstMonth: control<String>(firstMonth).value!,
    );

    return result.when((id) => id, (failure) {
      _applyFailure(failure);
      return null;
    });
  }

  Future<String?> _update() async {
    final before = _expenseOnOpen!;

    final newNotes = Patch<String>.diff(_notes, before.notes);
    // Tag não usa Patch: sendo obrigatória (TAG-06), não existe "limpar", só
    // trocar — então null aqui só pode significar "não mexi".
    final newTagId = _tagId == before.tag.id ? null : _tagId;
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
        newTagId == null &&
        !newNotes.changesSomething &&
        !newCard.changesSomething;

    // Salvar sem ter mexido em nada seria um `PATCH` de corpo vazio, e o
    // backend responde 400. Prender quem só abriu e fechou seria absurdo, então
    // a tela fecha como se tivesse salvo — porque, em efeito, salvou.
    if (nothingChanged) return _id;

    final result = await _repository.updateDetails(
      _id!,
      description: newDescription,
      paymentMethod: newMethod,
      tagId: newTagId,
      notes: newNotes,
      creditCardId: newCard,
    );

    return result.when((_) => _id, (failure) {
      _applyFailure(failure);
      return null;
    });
  }

  String get _description => control<String>(description).value!.trim();

  String get _tagId => control<String>(tagId).value!;

  /// Observação vazia é `null`, e não `''`: o backend recusa string de tamanho
  /// zero, e vazio aqui quer dizer "sem observação".
  String? get _notes {
    final value = control<String>(notes).value?.trim() ?? '';
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
