# Regra dos controllers

Vale para tudo em `lib/features/*/controller/`. A referência é o
**`TagListController`** — controller novo se escreve igual a ele. Escrita em
11/09/2026.

## A forma

```dart
class TagListController extends BaseController with MessageMixin {
  final TagRepository _repository;
  final NavigationService _nav;
  TagListController({required this._repository, required this._nav});

  final _state = signal<ViewState<List<TagModel>>>(const Loading());
  ReadonlySignal<ViewState<List<TagModel>>> get state => _state;

  @override
  void onInit() async {
    super.onInit();
    await _load();
  }

  @override
  void dispose() {
    super.dispose();
    _state.dispose();
  }

  Future<void> _load() async {
    _state.value = const Loading();
    final result = await _repository.list();
    result.when(
      (success) => _state.value = Loaded(success),
      (err) => _state.value = Failed(err),
    );
  }

  Future<void> refresh() => _load();
}
```

- **`extends BaseController`**, com `MessageMixin` quando a tela dá recado.
- **Construtor de parâmetros nomeados**, com `required this._campo`.
- **Estado em `signal` privado**, exposto como `ReadonlySignal` por getter. A
  tela lê, nunca escreve.
- **`onInit` carrega, `dispose` libera** cada signal e cada form.
- **`_load` é privado; `refresh()` é a porta pública.** Quem chama de fora é a
  view, e só para repetir a busca.
- Resultado do repositório sempre por **`result.when(success, err)`**, virando
  `Loaded` ou `Failed`.

## O que não existe

**Sem `requestId`.** Nada de contador incrementado a cada busca para descartar
resposta atrasada. Decidido em 11/09/2026.

**Sem `silent`.** `load({bool silent = false})` não existe: rebuscar mostra o
estado de carregamento, e ponto. A tela cuida do que aparece durante ele.

Essas duas ficaram para trás em seis controllers antigos — `home`,
`expense_list`, `expense_detail`, `income_list`, `income_detail` e
`credit_card_expenses`. **Não sair tirando em mutirão**; alinhar ao mexer, e
sabendo o que muda:

- sem `requestId`, dois toques rápidos podem deixar a resposta antiga
  sobrescrever a nova;
- sem `silent`, o pull-to-refresh pisca o esqueleto por cima do conteúdo.

**Sem `BuildContext`.** Navegação pelo `NavigationService` injetado
(`_nav.pop()`), recado pelos `toastError` / `toastSucess` do `MessageMixin`.
Controller que importa `package:flutter/material.dart` está fazendo trabalho de
tela.

**Sem conta de model.** Soma, média e formatação são de quem desenha ou de um
util — ver `.claude/rules/models.md`.

## Mutação sem recarregar

Criar, editar e excluir **reescrevem a lista a partir do `Loaded` atual**, sem
voltar à rede:

```dart
final current = _state.value;
if (current is! Loaded<List<TagModel>>) return;
...
final newList = [...current.data]..sort(...);
_state.value = Loaded(newList);
```

Só o `refresh()` busca de novo.

## Reagir à competência

Quando a tela depende do mês selecionado, o controller **se inscreve** — e essa
inscrição já é a carga inicial:

```dart
EffectCleanup? _watchingMonth;

@override
void onInit() {
  super.onInit();
  _watchingMonth = effect(() {
    _selectedMonth.month.value;   // a dependência, declarada por leitura
    untracked(_load);             // o trabalho, fora do rastreio
  });
}

@override
void dispose() {
  _watchingMonth?.call();
  super.dispose();
  _state.dispose();
}
```

Um `_load()` no `onInit` **além** do efeito duplica a primeira requisição. E
sem o `_watchingMonth?.call()` no `dispose` a inscrição vive a sessão inteira,
buscando com a tela fechada.

## Registro no get_it

- **`lazySingleton` com `dispose:`** para tela de lista, cujo estado vale
  preservar entre idas e vindas. A página chama
  `getIt.resetLazySingleton<X>()` no `dispose`, e é aí que o `dispose:` roda.
- **`factory`** para formulário e detalhe: estado por instância, não por app.
  Como `factory` não aceita `dispose:`, quem libera é o `dispose` da página.
