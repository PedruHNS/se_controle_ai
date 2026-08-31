# Roadmap — se_controle_ai

> ## 🔴 PENDÊNCIA URGENTE — a `API_KEY` de produção está exposta
>
> Vazou numa captura de tela em 21/08/2026, durante o deploy. Trocar exige as
> **duas pontas**: gerar outra no `.env` da VPS e **recompilar o app** com ela,
> porque a chave é gravada no binário pelo `--dart-define`. O passo a passo está
> no README do `expense-tracker-api`.
>
> Enquanto não for trocada, ela é a única coisa protegendo os dados — não há
> autenticação, e ela só chega na Fase 9.

App Flutter do controle de gastos, cliente da API `expense-tracker-api`
(Node + Express + Postgres, rodando em Docker na mesma máquina — e, desde
21/08, também numa VPS em `https://secontroleai.duckdns.org`).

## Onde estamos

*Atualizado em 31/08/2026 (quinta revisão).*

Flutter 3.44.9 · Dart 3.12.2 · **Fases 0 a 7 concluídas, Fase 9 em andamento** ·
a home mostra o resumo do mês, ganhos e gastos fixos têm CRUD completo com
reajuste, correção e encerramento, gasto parcelado tem reparcelamento e
quitação, cartões têm CRUD com a edição parcial do CAR-08, a projeção mostra
para onde o saldo caminha, um menu lateral na home leva a todas elas — e agora
o app entra pelo Firebase antes de qualquer uma, **e só por ele**: a
`x-api-key` saiu em 31/08.

**516 testes passando, nenhum falhando** · `flutter analyze` com um aviso
(`_createTag` não referenciado, em `expense_form_page.dart`).

**A última falha era o relógio, não o código, e o diagnóstico começou errado.**
`sem lista carregada, não chega a criar` passava sozinha e falhava na suíte
completa, o que parecia estado vazando entre arquivos de teste. Não era: o
`flutter test` roda os arquivos **em paralelo**, e o teste afirmava "ainda está
carregando" contando que 50 ms de `Future.delayed` não tivessem passado. Sob
carga o isolate fica sem CPU por mais que isso, o `list()` resolve antes da
asserção e o estado já é `Loaded`. Rodar com `-j 1` passava — foi o que mostrou
onde estava.

O conserto trocou o `delay` por um `Completer` que ninguém completa: pendente é
pendente, sem corrida. O mesmo padrão estava em **outros quinze lugares** —
ganhos, cartões, gastos, home e projeção —, e todos foram migrados no mesmo dia,
antes de perderem a corrida também. Onde o teste precisa ver o desfecho, ele
completa o future antes do `await`; onde só quer o estado do meio, nunca
completa. De quebra a suíte ficou mais rápida: ninguém mais espera 50 ms de
verdade.

**A refatoração de tags fechou em 27/08**, e com ela a dívida do comparador que
esta seção registrava. `TagModel` não é `Comparable` e **nunca teve** um
`byName` — a ordenação alfabética virou `TextOrder.alfabetica`, em
`lib/core/utils/text_order.dart`, que dobra caixa e acento e desempata pelo
texto original. Sem ela, `..sort()` cru estourava `type 'TagModel' is not a
subtype of type 'Comparable'` no clique de criar tag, e `'Água'` ia parar depois
de `'Transporte'`.

**Duas correções de sincronia na revisão anterior.** A versão declarada aqui era
Flutter 3.47.1 / Dart 3.13.1; a instalada é **3.44.9 / 3.12.2**, e o `pubspec`
pede `sdk: ^3.12.2`, que a instalada satisfaz. E o cabeçalho dizia "Fases 0 a
6" enquanto a tabela de fases já marcava a 7 como concluída — a tabela estava
certa.

**Em 27/08 os toasts do app passaram a aparecer.** A `Globals.navigatorKey` não
estava presa a widget nenhum, então o `currentContext` que o `MessageMixin`
consulta era sempre nulo e toda Flushbar era construída e descartada em
silêncio, sem erro nem log. A chave foi ligada no `GoRouter` — quem cria o
Navigator raiz é ele, e `MaterialApp.router` não aceita `navigatorKey`.

**No mesmo dia a edição de tag deixou de ser remendo.** `PATCH /tags/:id` virou
`POST /tags/:id`, que **substitui**: nome e cor vão sempre os dois, e omitir um
é 400 em vez de "não mexe". Some com isso o `Patch` do CAR-08 no caminho de tag
— `null` na cor só pode significar "sem cor". Gasto e cartão continuam com
`PATCH` e `Patch`, porque lá o formulário edita um punhado de campos por vez e
devolver o resto significaria reenviar dinheiro que ninguém tocou. A resposta
passou de 204 para 200 com a tag pronta, e criar, editar e excluir agora mexem
na lista em memória: nenhum dos três recarrega.

Em 21/08 o SDK subiu de 3.44 para 3.47.1 (Dart 3.13.1) — o `pubspec` já pedia
`sdk: ^3.12.2`, que o 3.12.0 instalado não satisfazia. No mesmo dia a seção de
débito da home passou a mostrar só as quatro linhas mais recentes, com o backend
entregando a lista já ordenada (ver a convenção de ordem abaixo), e o
`_defaultBaseUrl` foi corrigido depois que a rede local trocou de sub-rede.

**A Fase 7 fechou no mesmo dia**: tema claro/escuro seguindo o sistema,
transição entre os estados das telas, o estado vazio extraído para um widget só
e o identificador do template trocado por `com.secontroleai.app` — nos dois
sistemas, porque o iOS estava com o mesmo problema.

**Ainda em 21/08 entraram as tags**, com a Etapa 6 do backend. A categoria em
texto livre do gasto virou uma **tag obrigatória**, escolhida num seletor que
também cria tag nova sem sair do formulário — sem isso, precisar de um rótulo
novo obrigaria a abandonar o cadastro pela metade, o que seria pior que o texto
livre. O ganho ganhou o mesmo seletor, opcional. Entrou junto um campo de
**observação**, texto livre e opcional, que aparece só no detalhe do gasto:
nada o consulta, então mostrá-lo na lista roubaria espaço do que agrupa.

A **tela de tags** deixou de ser placeholder e virou CRUD completo: lista com
contagem de uso, criar, editar e excluir em diálogo, e uma seção de arquivadas
com restaurar. Sem tela de detalhe nem formulário de página inteira — a tag tem
dois campos e nenhum histórico, e uma tela cheia para isso seria navegação sem
conteúdo.

**Excluir tag em uso arquiva.** A tag continua nos lançamentos que já a usam e
sai das opções de lançamento novo, com o diálogo avisando disso **antes** de
confirmar — decidir sem saber o desfecho é decidir no escuro. Editar continua
valendo para trás (TAG-03): renomear muda o rótulo em todos os meses, inclusive
nos fechados, e vale também para tag arquivada.

O único teste vermelho que havia — `app_router_test` procurando uma linha
"Cartões" que nunca chegou a existir na home — foi reescrito na Fase 4 para
andar pelo menu lateral, que é por onde o caminho existe de verdade.

Em 19/08, antes de abrir a Fase 3, foram fechadas duas dívidas que a fase nova
ia copiar: a guarda de corrida existia só no `HomeController` (ver a convenção
abaixo) e o `app_router_test` cobria um botão que a home não tem. No mesmo dia o
atalho de voltar ao mês atual saiu do `bottom` do AppBar, onde empurrava o nome
do mês para fora da barra.

**Em 26/08 entrou a autenticação**, com a Etapa 7 do backend. O app deixou de
abrir direto na home: sem sessão, qualquer rota cai no login, e toda requisição
passa a levar `Authorization: Bearer` com o ID token do Firebase. O login é
**só pelo Google**, e desde 27/08 isso é decisão e não etapa: o GitHub saiu do
corte antes de virar código. Ele custava um caminho inteiro à parte
(`signInWithProvider` com Custom Tabs, esquema de URL para o deep link voltar) e
trazia junto o fluxo de vinculação de contas, porque e-mail privado no GitHub
chega como `@users.noreply.github.com` e viraria uma segunda conta vazia. Com um
provedor só, nada disso existe.

Entrou junto — e saiu — o **403 de acesso pendente** (AUT-11). Ele teve exceção,
falha e card próprios sob o título "Aguardando aprovação"; em **27/08 a regra
foi retirada**, e essa tela deixou de existir em qualquer hipótese: quem se
cadastra tem acesso ao app. Sumiram junto a `PendingApprovalException`, a
`PendingApprovalFailure`, o caso 403 do `exception_mapper` e as duas linhas do
card — o app não tem mais nenhum tratamento de 403, e é para não ter mesmo.

Em **31/08 a `x-api-key` saiu também**, e com ela o último header fixo do Dio.
Ela conviveu com o token por cinco dias, e o que a derrubou não foi a
redundância: é que ela nunca foi segredo depois do build — uma string só, igual
em todos os aparelhos, sem validade, legível com `strings -a app-release.apk`.
O token é por pessoa, expira em uma hora e é verificado por assinatura. **Quem
autentica agora é só o Google.**

As libs de runtime em uso, mais o `mocktail` nos testes:

| Lib | Versão | Papel no app |
|---|---|---|
| `dio` | ^5.11.0 | Cliente HTTP: baseUrl, timeouts, interceptors |
| `multiple_result` | ^5.3.0 | `Result<Sucesso, Falha>` — erro como retorno, não exceção |
| `get_it` | ^9.2.1 | Service locator: Dio, ApiClient, repositórios, controllers |
| `go_router` | ^17.5.0 | Navegação declarativa por rota nomeada + deep link |
| `signals` | ^7.1.0 | Estado reativo: `signal` no controller, `SignalBuilder` na view |
| `pretty_dio_logger` | ^1.4.0 | Log de requisição/resposta em debug, só quando `AppConfig.logHttp` |
| `reactive_forms` | 18.2.2 | Campos, validação e erro de formulário como estado, não como widget |
| `firebase_core` | ^4.14.0 | Inicializa o SDK antes do `runApp`, com as opções do `firebase_options.dart` |
| `firebase_auth` | ^6.6.0 | A sessão: guarda, restaura e renova o ID token sozinho |
| `google_sign_in` | ^7.2.0 | A escolha de conta do Android. **v7**: `instance.initialize()` + `authenticate()`, e não o `signIn()` da v6 |
| `mocktail` | ^1.0.5 | Dev: mocks dos repositórios e do `HttpClientAdapter` nos testes |

### O `ApiClient` devolve `Response`, não JSON cru

Mudou em 18/08, e é a decisão que mais afeta quem for escrever o próximo
repositório. `ApiClient.get`/`post`/`delete` devolvem o `Response` do Dio; o
corpo desserializado está em `response.data`.

```dart
final response = await _api.get('/summary', queryParameters: {'month': month});
return Success(MonthlySummaryModel.fromJson(Decode.object(response.data)));
```

**O `.data` não é opcional, e esquecê-lo é silencioso.** O retorno é `dynamic`,
então a omissão passa pelo `flutter analyze` e só aparece como `TypeError` em
runtime — capturado pelo `catch` genérico do repositório e servido como
`SerializationFailure`, ou seja, tela de erro sem pista da causa. Foi o que
aconteceu quando o contrato mudou: a home quebrou e `getProjection` ficou
quebrado mais tempo ainda, porque o fake do teste não passa pelo `ApiClient`.
Quem guarda essa fronteira é o grupo `devolve o Response do Dio` em
`api_client_test.dart`.

### Duas convenções, agora fechadas

Estavam pela metade e foram alinhadas em 18/08, antes de abrir a Fase 2 — cada
feature nova copia essas duas escolhas, então valia resolver com uma feature só
no repositório.

**Todo model termina em `Model`.** `MonthlySummaryModel`, `SummaryLineItemModel`,
`DebitGroupModel`, `CreditCardInvoiceModel`, `MonthProjectionModel` — um por
arquivo `*_model.dart`. O sufixo também separa o model do widget de mesmo assunto:
`CreditCardInvoiceModel` é o dado, `CreditCardInvoiceCard` é a tela.

**Controller é `registerLazySingleton`, e quem libera é o get_it.** O dono da
instância é o container, não a tela: a página só faz `getIt<XController>()` e
**não** chama `dispose` — quem libera os signals é o `dispose:` do registro.
Consequência desejada: sair da home e voltar reaproveita o mesmo controller, e o
mês selecionado sobrevive à navegação em vez de recomeçar no atual.

A contrapartida é que o estado é único por app. Quando a mesma rota pode ser
empilhada duas vezes com estados diferentes, o registro vira `registerFactory` e o
`dispose` passa para o `State` da página — factory não aceita o `dispose:`,
porque o get_it não guarda a instância. É o caso do formulário e do detalhe de
ganho.

**No construtor de um controller entram apenas dependências — repositório ou
service. Nunca um valor.** Nem id, nem mês, nem filtro. O construtor é o ponto de
injeção; misturar dado com dependência amarra a construção do controller a ter o
valor em mãos, e obriga o registro a virar `registerFactoryParam` em vez do
`registerFactory` que todos os outros usam.

Dado de rota é entregue **pela view**, depois da construção: a página chama
`controller.start(widget.id)` no `initState` e o controller guarda o valor. É como
o `IncomeDetailController` funciona. A consequência aceita é que esse controller
**não** busca no `onInit` — ali o valor ainda não chegou. `registerFactoryParam`
não é usado em nenhum lugar do projeto.

Um detalhe que o `test_injector.dart` deixa de fora: lá o `HomeController` é
`registerFactory`, para cada teste começar limpo. É divergência de propósito, mas
significa que o caminho de `dispose` de produção não é exercitado por teste.

**Controller consome `Result` com `.when`, nunca com `switch`.** Uma forma só em
todo o projeto, para não haver duas maneiras de ler a mesma coisa:

```dart
final result = await _repository.getMonthly(month: _month.value);

result.when(
  (success) => _state.value = Loaded(success),
  (err) => _state.value = Failed(err),
);
```

Fechado em 19/08 — o `HomeController` era o único que ainda usava `switch` com
os padrões `Success`/`Error`. Efeito colateral bem-vindo: o controller não
importa mais `multiple_result`, porque `Success` e `Error` só aparecem no
repositório. Quando o retorno interessa em vez do estado — as ações que devolvem
`Failure?` do `IncomeDetailController` — é o mesmo `.when`, devolvendo valor
pelos dois braços.

**Todo controller que busca tem a guarda de `_requestId`.** Duas buscas em voo
voltam fora de ordem, e sem o contador a resposta velha ganha da nova:

```dart
Future<void> load({bool silent = false}) async {
  final requestId = ++_requestId;
  ...
  if (requestId != _requestId) return;   // resposta atrasada: descarta
  result.when(...);
}
```

Fechado em 19/08. Existia só no `HomeController`, onde o gatilho é óbvio (toque
rápido em duas setas de mês); nos de ganho o gatilho é mais discreto — cada ação
termina numa recarga silenciosa, então duas ações em sequência deixam duas buscas
em voo. O teste que cobre isso na lista de ganhos **já existia e falhava** desde a
Fase 2: foi escrito junto com o controller, e a guarda nunca entrou.

### O menu lateral é a porta das telas de cadastro

Entrou em 19/08. A home é a única tela que não foi empilhada por outra, então o
`Drawer` mora só nela: das demais se sai pelo "voltar", e um menu repetido lá
daria caminho de ida para onde já se está. Os itens navegam com `pushNamed` e não
`go`, para o "voltar" da tela nova devolver para a home — e fecham o menu antes
de navegar, senão o `Drawer` aberto fica no histórico local e o primeiro "voltar"
só o fecharia.

**O menu custou o `leading` da AppBar, e quem pagou a conta foi o rótulo do mês.**
O hambúrguer só aparece sozinho quando o `leading` está livre, e ali estava a seta
do mês anterior. As duas setas foram para a direita, ao lado do sino de
notificações — e com quatro ícones dividindo a barra, "Agosto 2026" deixou de
caber: era cortado em "Agost…", sem o ano, em qualquer tela abaixo de 411dp. O
título passou a `Month.shortLabel` (`ago/2026`), a AppBar perdeu os 16px de
`titleSpacing` padrão de cada lado, e o texto encolhe por `FittedBox` em vez de
ser cortado. `home_page_test` mede isso a 360dp, no caso irmão do que já guardava
o eixo vertical.

**Notificações ainda é tela de aviso; tags deixou de ser.** As duas entraram no
menu antes de existirem no backend, com estado vazio explicado, porque item de
menu que não faz nada ao ser tocado é pior do que um que diz por quê.

Tags virou tela de verdade em 21/08, junto com a Etapa 6 do backend
(`docs/specs/06-tags.md`) — sem virar fase própria, como previsto: foi cadastro
simples que veio junto com o endpoint. Notificações continua esperando a Etapa 8
(`docs/specs/07-notificacoes.md`) e, do lado do app, é a **Fase 10** — era a 9
até o login entrar na frente e empurrar as duas últimas uma casa cada.

**O corpo da home virou `CustomScrollView`.** A faixa de "voltar para o mês atual"
é um `PinnedHeaderSliver`: fixa abaixo da AppBar e medida pela altura do próprio
filho, sem o delegate de extents fixos que o `SliverPersistentHeader` exigiria.
Efeito colateral desejado — o `RefreshIndicator` subiu para fora do conteúdo, e o
pull-to-refresh passou a valer também nas telas de carregando e de erro, que
antes não tinham como pedir os dados de novo a não ser pelo botão do card.

### O que já existe em `lib/`

| Arquivo | O que faz |
|---|---|
| `main.dart` · `app.dart` | Entrada: injector antes do `runApp`, MaterialApp.router |
| `core/theme/app_theme.dart` | Os dois temas do mesmo seed, e a `ThemeExtension` do alerta que o `ColorScheme` não tem |
| `core/shared/widgets/empty_state_widget.dart` | Estado vazio com o scroll e o pull-to-refresh embutidos |
| `core/shared/widgets/state_transition.dart` | Fade entre carregando, erro e conteúdo. Pede `stateKey` porque sem chave o `AnimatedSwitcher` é inerte |
| `core/config/app_config.dart` | baseUrl por plataforma + `--dart-define=API_BASE_URL`, timeouts, `logHttp` |
| `core/config/globals.dart` | A `navigatorKey` do Navigator raiz — é ela que dá contexto ao toast fora da árvore — e a paleta de cores das tags |
| `core/shared/mixin/message_mixin.dart` | `toastError` e `toastSucess`: Flushbar pela `Globals.navigatorKey`, sem precisar de `BuildContext` |
| `core/network/dio_factory.dart` | Monta o Dio: BaseOptions, o `AuthInterceptor` e o `PrettyDioLogger` quando `logHttp` |
| `core/network/auth_interceptor.dart` | Põe o Bearer em toda requisição e, num 401, renova à força e repete **uma** vez |
| `core/router/auth_refresh.dart` | `ChangeNotifier` sobre o stream de sessão — é o que faz o `redirect` rodar quando alguém sai |
| `data/models/auth_user_model.dart` | Quem está logado, sem o `User` do Firebase vazar para tela e controller |
| `data/repositories/auth_repository.dart` | Entrar, sair e o token. Inclui o port `GoogleIdentity`, porque o `GoogleSignIn` da v7 é singleton de construtor privado |
| `features/auth/controller/login_controller.dart` | Estado da tela: quem entrou, trabalhando e a última falha |
| `features/auth/view/login_page.dart` | A tela de entrar. Sem campo nenhum — a identidade vem de fora |
| `core/errors/app_exception.dart` | O que a infra **lança** — técnico: status, código, causa, stack |
| `core/network/exception_mapper.dart` | Único lugar que conhece `DioException` → `AppException` |
| `core/errors/failure.dart` | O que a UI **recebe** — `Failure.fromException` traduz para o usuário |
| `core/network/api_client.dart` | Fala HTTP: devolve o `Response` e **lança** `AppException` |
| `core/di/injector.dart` | Registro no get_it: Dio, ApiClient, repositório, controller |
| `core/router/app_routes.dart` | Nomes e caminhos de rota centralizados |
| `core/router/app_router.dart` | Instância do GoRouter, o `redirect` de sessão e a tela de 404 |
| `core/shared/view_state.dart` | `Loading` / `Loaded` / `Failed` para a view dar switch exaustivo |
| `core/shared/patch.dart` | `Patch<T>`: os três estados de um campo de `PATCH` — `keep`, `clear`, `to` |
| `data/models/amount_version_model.dart` | `AmountVersionModel` — uma vigência de valor; serve ganho **e** gasto |
| `core/shared/widgets/app_drawer.dart` | Menu lateral da home: ganhos, gastos, cartões, tags — e o sair, com a conta atual embaixo |
| `core/shared/widgets/amount_history_card.dart` | A linha do tempo de vigências, usada por ganho e por gasto |
| `core/shared/widgets/failure_card_widget.dart` | Card de erro único, com ícone e título por tipo de `Failure` |
| `core/shared/forms/money_value_accessor.dart` | Ponte entre `FormControl<int>` em centavos e o texto do campo |
| `core/shared/widgets/money_field_widget.dart` | `ReactiveTextField<int>` de dinheiro, com as mensagens de erro do valor |
| `core/shared/widgets/month_field_widget.dart` | `ReactiveFormField<String>`: competência por setas, com piso (`minMonth`) para travar o que a regra recusaria |
| `core/shared/widgets/day_field_widget.dart` | `ReactiveFormField<int>`: dia 1–31 por setas, circular na virada |
| `core/utils/base_controller.dart` | Ciclo de vida do controller: `onInit`, `onReady`, `dispose`, com log |
| `core/utils/money.dart` | Centavos ↔ real: `format`, `formatSigned`, `formatCompact`, `tryParse` |
| `core/utils/month.dart` | Competência `YYYY-MM`: label, aritmética, limites do backend |
| `core/utils/iso_date.dart` | Data `YYYY-MM-DD` → `17/08` ou `17/08/2026`, por corte de string |
| `core/utils/text_order.dart` | `TextOrder.alfabetica`: ordem alfabética dobrando caixa e acento, desempatando pelo texto original. `TagModel` não é `Comparable`, e `..sort()` cru estourava |
| `data/models/monthly_summary_model.dart` | `MonthlySummaryModel` — a resposta de `/summary` inteira |
| `data/models/summary_line_item_model.dart` | `SummaryLineItemModel` — a linha usada em ganho, débito e fatura |
| `data/models/debit_group_model.dart` | `DebitGroupModel` — total + itens do débito |
| `data/models/credit_card_invoice_model.dart` | `CreditCardInvoiceModel` — fatura do mês, com `limitUsage` |
| `data/models/month_projection_model.dart` | `MonthProjectionModel` — um mês de `/summary/projection` |
| `data/repositories/summary_repository.dart` | Interface + impl de `/summary` e `/summary/projection` |
| `features/home/controller/home_controller.dart` | Estado do resumo com signals — **é o molde a copiar** |
| `features/home/view/home_page.dart` | A tela: `CustomScrollView` com a faixa fixa, navegação de mês, `switch` no `ViewState`, pull-to-refresh |
| `features/home/widgets/` | `BalanceCard`, `SummarySection` (com o teto de linhas `maxItems`), `CreditCardInvoiceCard`, `LineItemTile` |
| `data/models/tag_model.dart` | A tag, com o parse tolerante de `#RRGGBB` para `Color` |
| `data/repositories/tag_repository.dart` | As quatro operações de `/tags` |
| `features/tags/view/tag_list_page.dart` | O CRUD de tags, com a seção de arquivadas e o restaurar |
| `features/tags/controller/tag_list_controller.dart` | Estado da lista; o `delete` devolve se arquivou ou apagou |
| `features/tags/widgets/create_tag_dialog_widget.dart` | Cria tag com paleta fixa em vez de seletor livre de cor. Serve a tela de tags e o formulário de gasto |
| `features/tags/widgets/tag_tile_widget.dart` | A linha da tag na lista |
| `features/projection/` | Controller, tela e o `ProjectionChart` — barras do acumulado, sem biblioteca |
| `data/models/income_model.dart` · `income_version_model.dart` | O ganho e suas vigências |
| `data/repositories/income_repository.dart` | As sete rotas de `/incomes`, com reajuste e correção separados |
| `features/incomes/controller/` | `IncomeListController`, `IncomeFormController`, `IncomeDetailController` |
| `features/incomes/view/` | Lista, formulário e detalhe |
| `features/incomes/widgets/` | `IncomeTile`, `IncomeHistoryCard`, e os diálogos de valor e encerramento |
| `data/models/credit_card_model.dart` | `CreditCardModel` — o cartão do CRUD, **não** a fatura do resumo |
| `data/repositories/credit_card_repository.dart` | As cinco rotas de `/credit-cards`, com o `PATCH` do CAR-08 |
| `features/credit_cards/controller/` | `CreditCardListController` (lista + exclusão), `CreditCardFormController` (cadastro + edição) |
| `features/credit_cards/view/` | Lista, formulário e a tela do cartão com os gastos dele |
| `features/credit_cards/widgets/` | `CreditCardTile` |
| `data/models/expense_model.dart` | `ExpenseModel` + os enums `ExpenseType` e `PaymentMethod` |
| `data/models/installment_model.dart` | `InstallmentModel` — uma parcela; o "de N" muda no reparcelamento |
| `data/repositories/expense_repository.dart` | As oito rotas de `/expenses` que a Fase 4 usa; parcelado fica para a Fase 5 |
| `features/expenses/controller/` | `ExpenseListController`, `ExpenseFormController` (cadastro + edição), `ExpenseDetailController` |
| `features/expenses/view/` | Lista, formulário e detalhe |
| `features/expenses/widgets/` | `ExpenseTile`, `InstallmentsCard` e os quatro diálogos: valor, encerramento, reparcelamento e quitação |
| `features/notifications/view/notification_list_page.dart` | Só o estado vazio — o servidor ainda não manda notificação |

**Um model por arquivo, sem barrel.** Cada consumidor importa o arquivo da classe
que usa. Não existe `models/monthly_summary.dart` reexportando o resto — quem
precisa de `CreditCardInvoiceModel` importa `credit_card_invoice_model.dart`.

### O que já existe em `test/`

| Arquivo | O que faz |
|---|---|
| `fixtures/summary_fixture.dart` | JSON real capturado do backend: mês normal, vazio e no vermelho |
| `fixtures/test_injector.dart` | Registra as dependências das telas com os fakes; idempotente entre testes |
| `fixtures/income_fixture.dart` | JSON de `/incomes`: salário, salário reajustado, 13º e o avulso por competência |
| `fixtures/mocks.dart` | Os mocks de repositório e os stubs padrão (`stubMonthly`, `stubIncomeList`, `stubCreditCardList`…), mais o `capturedUpdateBody` que anota o corpo do `PATCH` |
| `core/theme/app_theme_test.dart` | Os dois temas, a extensão de cor e a elevação zerada do card |
| `core/shared/empty_state_test.dart` | O gesto de recarregar sobrevivendo à lista vazia |
| `core/shared/state_transition_test.dart` | Que a transição de fato acontece — inclusive entre dois estados que renderizam o mesmo widget, que é o caso que a versão sem `stateKey` deixava passar |
| `core/utils/iso_date_test.dart` | 6 casos do formato de data, incluindo entrada fora do formato |
| `fixtures/credit_card_fixture.dart` | JSON real de `/credit-cards`: cartão completo, cartão sem os opcionais, e sem competência |
| `core/shared/patch_test.dart` | Os três estados do `Patch` e o `diff` que decide entre eles |
| `features/home/home_navigation_test.dart` | O menu abre com os cinco destinos, cada um chega na tela certa, e o sino leva às notificações |
| `fixtures/projection_fixture.dart` | JSON real de `/summary/projection`: seis meses no azul, e os mesmos seis com uma reforma de R$ 50.000,00 |
| `fixtures/expense_fixture.dart` | JSON real de `/expenses`: aluguel com dois valores vigentes, gasto no cartão, avulso, e um parcelado antes e depois de reparcelado |
| `features/expenses/expense_installment_test.dart` | O que só o parcelado tem: plano, reparcelamento, quitação, e o formulário que troca de campos |
| `features/projection/projection_test.dart` | Horizonte, guarda de corrida e o aviso do primeiro mês no vermelho |
| `features/tags/tag_list_test.dart` | A tela de tags: seções, contagem de uso, o aviso de "vai arquivar" antes de confirmar, e o restaurar |
| `features/expenses/tag_test.dart` | O model da tag, o seletor obrigatório que bloqueia o salvamento, e o criar-sem-sair-do-formulário — inclusive o 409 de nome repetido, que fica no diálogo e não derruba a tela |
| `fixtures/tag_fixture.dart` | JSON real de `/tags`: as tags que a migration criou a partir das categorias |
| `features/home/summary_section_test.dart` | O teto de linhas da seção: ordem preservada sem reordenar, rodapé no singular e no plural, limite exato sem rodapé, e o total que não é recalculado sobre a fatia visível |

### Onde erro deixa de ser exceção e passa a ser valor

```
Dio  --DioException-->  exception_mapper  --AppException-->  ApiClient (lança)
                                                                  |
                              repositório: try/catch + decode  <--+
                                                                  |
                                            Result<T, Failure>  <-+  --> controller/UI
```

`ApiClient` devolve o `Response` e **lança**; `Result` nasce no repositório. O
molde de um método de repositório:

```dart
@override
Future<Result<MonthlySummaryModel, Failure>> getMonthly({String? month}) async {
  try {
    final response = await _api.get('/summary', queryParameters: {'month': month});
    return Success(MonthlySummaryModel.fromJson(Decode.object(response.data)));
  } on AppException catch (exception) {
    return Error(Failure.fromException(exception));
  } catch (error, stackTrace) {
    return Error(_serializationFailure(error, stackTrace));
  }
}
```

Três consequências para quem escreve código:

- **Repositório é o único lugar com decode e com `try/catch`.** Nunca escreva
  `try/catch` em controller ou widget.
- **`AppException` só circula entre `ApiClient` e repositório**; `Failure` só
  circula dali para cima. Se um `AppException` chegou a um widget, algo furou a
  camada.
- **O decode fica dentro do `try`, e existe um `catch` genérico depois do
  `on AppException`.** `on AppException` não pega o `TypeError` de um cast, então
  sem essa rede um contrato quebrado no backend viraria crash em vez de `Failure`.
  O `_serializationFailure` embala o erro num `SerializationException` e devolve
  como valor. Foi essa rede que transformou a regressão do `ApiClient` em tela de
  erro em vez de tela branca — útil, e também o motivo de ela ter passado
  despercebida por um tempo.
- **O `try/catch` fica escrito em cada método, e não num helper que recebe uma
  closure.** Os repositórios de ganho, cartão e gasto chegaram a ter um `_guard`
  que embrulhava o corpo de cada operação; foi removido em 20/08. A repetição é o
  preço de o tratamento de erro ficar visível onde ele acontece — quem lê um
  método vê o que ele faz com a falha sem sair dali, e um método que precise
  tratar um caso a mais não briga com a forma do helper. O único trecho
  compartilhado é o `_serializationFailure`, que é uma função pura de duas
  linhas, não uma moldura de controle de fluxo.

Cada nível tem função distinta: o mapper **classifica** (qual falha técnica foi),
o `Failure` **traduz** (o que o usuário lê). É por isso que um 500 com
`TypeError: x is not a function` mostra "O servidor falhou ao processar" na tela
e guarda o stack do Node em `failure.exception`, para log.

---

## O contrato do backend

Toda a superfície que o app tem para consumir. Dinheiro **sempre em centavos
(int)**; competência **sempre string `YYYY-MM`**.

**Toda rota exige `Authorization: Bearer <ID token>`, menos `/health`** (AUT-05).
Não há rota de login, cadastro, refresh nem logout: a identidade vem do
Firebase, e a única rota que a Etapa 7 acrescentou é o `GET /me`, que confirma a
sessão. **É a única credencial que o app manda**: a `x-api-key` saiu em 31/08.

Dois status novos vieram junto. **401** deixou de significar só "a chave do
build está errada" e passou a incluir token ausente, expirado ou inválido — o
interceptor renova e repete uma vez antes de deixá-lo subir. **403 não existe**:
houve um, de 26 a 27/08, para o cadastro à espera de aprovação (AUT-11), e saiu
com a regra. "Não é você" é 401, "não é seu" é 404, e não há terceiro caso.

E **nenhum corpo de resposta ganhou `userId`**: o dono é implícito, porque é
sempre quem está perguntando.

**Mutação responde 204, sem corpo.** Reajuste, correção, encerramento,
reparcelamento, quitação e os `PATCH` de edição não devolvem o recurso
atualizado — quem precisa do estado novo relê. Só `POST` de criação foge disso,
com 201 e o corpo do que foi criado.

**A ordem dos itens do resumo é contrato, não acaso.** Dentro de cada
competência, o backend entrega do lançamento criado mais recentemente para o
mais antigo, com a descrição como desempate. Vale para `debit.items` e para os
itens de cada fatura. É o que permite à home cortar a lista nas primeiras linhas
sem esconder o que acabou de ser cadastrado — e é por isso que o app **não**
reordena: `createdAt` não vem no payload, então ordenar no cliente só
conseguiria alfabético.

### Resumo — a tela inicial em uma chamada
| Método | Rota | Observação |
|---|---|---|
| GET | `/summary?month=YYYY-MM` | Sem `month`, usa o mês corrente |
| GET | `/summary/projection?from=YYYY-MM&months=N` | `N` de 1 a 60, default 12 |

`/summary` devolve `incomeCents`, `expenseCents`, `balanceCents`,
`committedPercent`, a lista de ganhos, o grupo `debit` e um `creditCards[]` com
a fatura de cada cartão (com `label`, `dueDate`, `limitCents`, itens).

### Ganhos
| Método | Rota | Semântica |
|---|---|---|
| POST | `/incomes` | `{description, amountCents, startMonth, recurring?, tagId?}` — `recurring` default `true`, `tagId` opcional |
| GET | `/incomes?month=` · `/incomes/:id?month=` | `amountCents` = valor vigente no mês |
| POST | `/incomes/:id/adjustments` | Aumento: preserva os meses anteriores |
| PATCH | `/incomes/:id/amount` | Correção: o valor estava errado desde o início |
| POST | `/incomes/:id/closure` | `{lastMonth}` — parei de receber |
| DELETE | `/incomes/:id` | |

**Reajuste e correção são operações diferentes** e a UI precisa deixar isso
explícito — não são dois caminhos para "editar valor".

### Tags
| Método | Rota | Semântica |
|---|---|---|
| POST | `/tags` | `{name, color?}` → **a tag inteira** + `restored`. Nome repetido ignorando caixa é 409; nome de arquivada ressuscita aquela linha (TAG-17) e volta com o `usageCount` que ela acumulou |
| GET | `/tags?includeArchived=` | Por nome, com `usageCount`. Sem o parâmetro, só as ativas — e o app deixou de mandá-lo em 27/08, porque a seção de arquivadas saiu da tela |
| POST | `/tags/:id` | **Substitui**: nome e cor sempre os dois, `null` limpa a cor. Devolve a tag no formato do item de listagem, com `usageCount`, para a tela trocar a linha sem recarregar. Era `PATCH` até 27/08 |
| DELETE | `/tags/:id` | Sem uso apaga; em uso **arquiva**. 200 com `{archived}` |
| POST | `/tags/:id/restore` | Traz a arquivada de volta |

**A tag é a categoria, e é obrigatória no gasto.** Não existem os dois
conceitos: `category`, que era texto livre, foi removida. No ganho a tag é
opcional — exigir rótulo para lançar salário obrigaria a inventar um.

**Excluir tag em uso arquiva, não apaga nem recusa.** A tag continua nos
lançamentos que já a usam e sai das escolhas de lançamento novo — usá-la em
gasto ou ganho novo é 422. Isso tem uma consequência para o app: o seletor pede
só as ativas, mas **ao editar um gasto cuja tag foi arquivada depois, ela
precisa entrar na lista** — um `DropdownButtonFormField` com valor sem item
correspondente é assertion do Flutter, não campo vazio.

### Cartões
| Método | Rota |
|---|---|
| POST · GET · GET/:id · PATCH/:id · DELETE/:id | `/credit-cards` (`?month=` resolve `dueDate`) |

### Gastos
| Método | Rota | Semântica |
|---|---|---|
| POST | `/expenses` | Discriminado por `type`: `FIXED` ou `INSTALLMENT`. `tagId` **obrigatório**, `notes` opcional |
| GET | `/expenses?month=&type=&paymentMethod=&creditCardId=` | Filtros combináveis |
| GET | `/expenses/:id?month=` | |
| PATCH | `/expenses/:id` | Só descrição/tag/observação/forma de pagamento |
| POST | `/expenses/:id/adjustments` · PATCH `/amount` · POST `/closure` | Só `FIXED` |
| POST | `/expenses/:id/reschedule` · POST `/settlement` | Só `INSTALLMENT` |
| DELETE | `/expenses/:id` | |

**Os dois tipos não compartilham operação de dinheiro.** `FIXED` tem vigências
(`history`), `INSTALLMENT` tem parcelas (`installments`), e o campo do outro tipo
vem `null`. Isso precisa virar duas telas de edição distintas, não uma com ifs.

### Erros
Envelope único: `{code, message, issues?: [{path, message}]}`.

| Status | Significa | O que a UI faz |
|---|---|---|
| 400 | Dados inválidos (zod) | `issues[].path` → erro embaixo do campo |
| 404 | Não existe | Volta e avisa que sumiu |
| 409 | Vigências sobrepostas | Explica o conflito |
| 422 | Regra de negócio violada | Mensagem do backend, direto |
| 5xx | Falha do servidor | "Tente novamente" |

---

## Fases

Ordem escolhida para que cada fase só dependa das anteriores, e para que a
primeira tela já valide a stack inteira antes de existir formulário.

| | |
|---|---|
| ▓▓▓▓▓▓▓▓▓▓ | Fase 0 — Fundação: **concluída** |
| ▓▓▓▓▓▓▓▓▓▓ | Fase 1 — Resumo mensal: **concluída** |
| ▓▓▓▓▓▓▓▓▓▓ | Fase 2 — Ganhos: **concluída** |
| ▓▓▓▓▓▓▓▓▓▓ | Fase 3 — Cartões: **concluída** |
| ▓▓▓▓▓▓▓▓▓▓ | Fase 4 — Gastos fixos: **concluída** |
| ▓▓▓▓▓▓▓▓▓▓ | Fase 5 — Gastos parcelados: **concluída** |
| ▓▓▓▓▓▓▓▓▓▓ | Fase 6 — Projeção: **concluída** |
| ▓▓▓▓▓▓▓▓▓▓ | Fase 7 — Acabamento: **concluída** |
| ░░░░░░░░░░ | Fase 8 — Qualidade: não iniciada |
| ▓▓▓▓▓▓▓▓▓░ | Fase 9 — Login: **em andamento** — Google provado em aparelho, token e guarda de rota prontos; falta o SHA-1 de release |
| ░░░░░░░░░░ | Fases 10 e 11 — não iniciadas |

A **Fase 11 — Offline-first** fecha a lista de propósito: ela é uma segunda
fonte da verdade, não um cache, e só sai barata com o contrato parado.

**Onde estamos: Fase 9, em andamento desde 26/08.** A Etapa 7 do backend ficou
pronta no mesmo dia e desbloqueou esta fase — a fila mudou: a Fase 8 (Qualidade)
não bloqueava nada e a autenticação bloqueava tudo, então ela passou na frente.

A Fase 7 fechou em 21/08 com tema claro/escuro, transição entre os estados das
telas, o estado vazio extraído para um widget só e o identificador do template
trocado nos dois sistemas. As duas decisões que estavam em aberto foram
fechadas: máscara ao vivo **não entra**, e o offline global **espera a Fase
11**.

As Fases 10 e 11 continuam **bloqueadas pelo backend**, e dependem das Etapas 8
e 9 de lá, nessa ordem.

Em 21/08 a autenticação deixou de ser decisão aberta e entrou como **Etapa 7 do
backend e Fase 9 daqui**, empurrando notificações e offline-first uma casa cada.
Ela entra cedo de propósito: obriga toda tabela a ganhar dono, e esse custo só
cresce com o número de tabelas.

No mesmo dia o backend jogou o fechamento (integração e deploy) para o fim, o
que **desbloqueia antes** — as etapas de que estas fases dependem deixaram de
esperar a suíte de integração.

Com as Fases 5 e 6, **as duas dívidas que vinham desde a Fase 3 foram pagas**: o
409 do CAR-07 foi exercitado ao vivo (excluir cartão com gasto vinculado devolve
`ConflictFailure`, "Cartão possui gastos vinculados"), e o teste de rota que
procurava uma linha inexistente na home foi reescrito na Fase 4.

### Fase 0 — Fundação · ▓▓▓▓▓▓▓▓▓▓ concluída
Nenhuma tela. Só o encanamento que todas as fases seguintes usam.

- [x] `core/config` — baseUrl por plataforma e `--dart-define`
- [x] `core/network` — Dio configurado + tradução de `DioException` para `Failure`
- [x] `core/errors` — `sealed AppException` (lançada) e `sealed Failure` (retornada),
      espelhando a tabela de status do backend
- [x] `core/di` — get_it com `Dio` e `ApiClient`
- [x] `core/router` — go_router com rotas nomeadas, `errorBuilder` e gancho de `redirect`
- [x] `core/shared/view_state.dart` — `Loading` / `Loaded` / `Failed`
- [x] `core/utils/money.dart` — formatação e parse de dinheiro
- [x] `core/utils/month.dart` — competência `YYYY-MM`: label em português,
      aritmética com virada de ano, limites 2000–2100 do backend
- [x] **Padrão de controller com signals + `Result`** — `HomeController` é o molde

**Pronto quando:** um `main.dart` sobe, resolve dependências do get_it, navega
por go_router e uma chamada de teste ao `/health` do backend volta `Success`.
→ **Esse critério já passa.** Verificado ao vivo contra o Docker: `/health` devolveu
`Success('ok')`, `/summary?month=2026-08` decodificou e formatou
(`R$ 5.000,00` / `R$ 2.455,90` / `+R$ 2.544,10`), 404 real virou `NotFoundFailure`
e 400 real virou `ValidationFailure` com as issues do zod.

**Testes que já cobrem a fase** (38 no total, todos passando):
`test/core/utils/money_test.dart` (17 casos: formatação, parse, round-trip),
`test/core/network/api_client_test.dart` (17 casos: 200/204, patch com corpo,
limpeza de query nula nos quatro métodos, 400 com issues, 404, 409, 422, 500,
corpo HTML de proxy, timeout, cancelamento, decode quebrado), `test/core/router/app_router_test.dart` (4 casos:
rota inicial, `goNamed`, 404, botão de voltar).

Os 4 casos do grupo `devolve o Response do Dio` são a única coisa que segura o
contrato do `ApiClient`, e os 4 de `query string` a única coisa que segura a URL
que sai — o resto do arquivo só olha o que é lançado. Método novo no client entra com caso novo nesse grupo.

### Fase 1 — Resumo mensal (home) · ▓▓▓▓▓▓▓▓▓▓ concluída
Só leitura. É a fase que prova a stack de ponta a ponta com o menor risco.

- [x] `GET /summary?month=` + navegação mês anterior / próximo, com atalho de
      voltar ao mês atual e setas desabilitadas nos limites do backend
- [x] Cartão de saldo com "Entra"/"Sai" e barra de `committedPercent`
      (laranja acima de 80%, vermelha acima de 100%)
- [x] Lista de débito e fatura por cartão, com uso do limite e aviso de estouro
- [x] Estados de carregando, vazio e erro; "tentar de novo" só em falha que vale
      repetir (`Failure.isRetryable`)
- [x] Pull-to-refresh que não pisca a tela — `load(silent: true)` mantém o
      conteúdo enquanto busca

**Pronto quando:** a home mostra o mês corrente com dados reais do Docker e
trocar de mês refaz a busca sem travar a UI. → **Atendido.**

**O que os testes da fase não cobrem:** todos entram pelo
`FakeSummaryRepository`, que não passa pelo `ApiClient`. Eles seguiram verdes
enquanto a home estava quebrada por causa do `.data` — é justamente o que um fake
não pega. Mudança na camada de rede tem que ser reconferida contra o Docker.

**Testes da fase** (59 no total, todos passando): `month_test.dart` (16 casos),
`monthly_summary_test.dart` (12 casos: parse do JSON real capturado do backend,
incluindo mês vazio e mês no vermelho, `limitUsage` e `MonthProjectionModel`),
`home_controller_test.dart` (16 casos: navegação, limites, corrida entre
respostas), `home_page_test.dart` (14 casos de widget), `widget_test.dart`
(1 caso: o app sobe e cai na home).

### Fase 2 — Ganhos · ▓▓▓▓▓▓▓▓▓▓ concluída
Primeiro CRUD, e o mais simples — é onde o padrão de formulário nasceu.

- [x] Listar, criar, encerrar, excluir
- [x] **Reajuste** e **correção** como ações distintas
- [x] Histórico de vigências visível
- [x] `issues[].path` do 400 ligado aos campos
- [x] Campos reutilizáveis: `MoneyFieldWidget` e `MonthFieldWidget`

**Pronto quando:** dá para cadastrar um salário, aplicar um aumento a partir de
um mês, e o resumo dos meses anteriores continua com o valor antigo.
→ **Atendido.** Verificado contra o Docker: ganho de 3.000 desde 2026-01,
reajustado para 4.000 a partir de 2026-08. `/summary?month=2026-05` ficou em
800.000 centavos, `/summary?month=2026-08` foi para 900.000. Reajuste retroativo
para 2026-01 voltou 422 com a mensagem pronta do backend.

**Três decisões desta fase**, que as próximas copiam:

**Reajuste e correção são métodos separados no repositório**, e dois caminhos
distintos na tela — não um "editar valor" com um `bool`. É a diferença que o
usuário precisa entender, e esconder atrás de um parâmetro seria escondê-la dele
também. O diálogo dos dois é o mesmo widget porque a única diferença de
formulário é o mês de vigência; o texto explicativo é que muda.

**As operações de ação devolvem `Failure?` em vez de guardá-la em signal.** Elas
são disparadas de dentro de um diálogo, e é lá que o erro precisa aparecer — o
422 de "reajuste retroativo" chega com a mensagem pronta em português. A tela de
trás continua mostrando o ganho: quem falhou foi a ação, não a busca.

**"Tem fim marcado" e "já acabou" são perguntas diferentes.** Ganho avulso —
venda, presente, 13º — nasce com `endMonth` preenchido, porque o backend fecha a
vigência na hora (GAN-02). Usar isso para marcar "Encerrado" na lista dizia que a
venda de agosto tinha acabado **em agosto**, com o dinheiro entrando. O model
separa as três perguntas: `isClosed` (aceita reajuste?), `isSingleMonth` (entra
uma vez só?) e `endedBefore(mês)` (ainda entra?). E o total da lista usa
`amountCentsIn(mês)`, lido do histórico, para bater exatamente com o número que a
home mostra — somar `amountCents` daria outro valor sempre que houver reajuste
agendado para o futuro.

**O formulário é estado, não widget.** O `FormGroup` mora no controller, com os
campos e as regras declarados uma vez (`Validators.required`, `Validators.min(1)`);
a view só faz o `bind` pelo nome do campo. Duas consequências que valem para toda
feature nova:

- **Dinheiro é `FormControl<int>` em centavos**, com o `MoneyValueAccessor`
  traduzindo para o texto do campo. `double` não aparece em nenhum ponto do
  caminho. O `reactive_forms` só devolve valor ao campo quando a mudança **não**
  veio dele, então digitar não é interrompido por reformatação — mas um
  `updateValue` feito em código chega formatado, e é assim que o diálogo de
  correção nasce preenchido.
- **`issues[].path` de um 400 vira `setErrors({'backend': mensagem})`** no control
  de mesmo nome. A mensagem se limpa sozinha na validação seguinte, ou seja,
  assim que a pessoa corrige o campo. `path` que não corresponde a campo nenhum
  sobe como falha geral — sem isso a tela recusaria sem dizer nada.

**A competência é seletor de setas, nunca campo de texto.** `MonthFieldWidget`
nasce válido por construção, e o `minMonth` trava no que a regra do backend
permite — no reajuste, o mês seguinte ao início da vigência atual (GAN-03/GAN-05).
Requisição que voltaria 422 nem sai.

**Testes da fase** (66 no total, todos passando): `income_model_test.dart`
(11 casos: parse com a resposta real do backend na fixture, valor por
competência, e a diferença entre "tem fim marcado" e "já acabou"),
`income_list_controller_test.dart` (6: busca, falha, refresh silencioso, corrida),
`income_form_controller_test.dart` (8: validação local, 400 campo a campo, falha
geral, `saving`), `income_detail_controller_test.dart` (8: reajuste vs. correção,
encerramento, recarga após 204, 422 devolvido ao diálogo),
`income_pages_test.dart` (14 de widget: lista com avulso, ganho já terminado,
vazio, erro, ações escondidas em ganho encerrado, histórico, diálogos),
`income_form_page_test.dart` (8 de widget: mensagens do submit vazio, centavos
digitados chegando inteiros, competência pela seta, 400 no campo e rede em
snackbar), `money_value_accessor_test.dart` (6), mais 3 casos novos em
`month_test.dart` para o `periodLabel`.

### Fase 3 — Cartões · ▓▓▓▓▓▓▓▓▓▓ concluída
Vem antes de gastos porque gasto no cartão exige `creditCardId`.

- [x] CRUD completo: listar, cadastrar, editar, excluir
- [x] `closingDay`/`dueDay` com seletor de dia (`DayFieldWidget`)
- [x] Limite opcional, e limpável
- [x] **Edição parcial do CAR-08**: campo ausente não muda nada, `null` limpa
- [x] 409 do CAR-07 explicado dentro do diálogo de exclusão
- [x] Porta para o cadastro — hoje o item "Cartões" do menu lateral. A linha na
      home, planejada aqui, nunca chegou a existir

**Pronto quando:** o cartão criado aparece como opção no formulário de gasto.
→ **Só fecha na Fase 4**, porque não existe formulário de gasto. O que dava para
verificar foi verificado ao vivo contra o Docker, pelo repositório de verdade:
criação, leitura com e sem `?month`, as duas direções do `PATCH`, listagem, 404,
400 com `issues` e exclusão. O `PATCH` só com o nome deixou dígitos e limite
intactos; o `PATCH` com `limitCents: null` limpou o limite e **não** tocou nos
dígitos.

**Quatro decisões desta fase:**

**`Patch<T>` — três estados onde o Dart só oferece dois.** O CAR-08 distingue
campo ausente de campo `null`, e um `int?` no parâmetro do repositório não
consegue dizer isso: `null` teria que significar "não mexi" e "apaga" ao mesmo
tempo. Então os dois campos limpáveis pedem `Patch<T>`, com `keep`, `clear` e
`to`. Os outros três não são anuláveis no backend (CAR-01/CAR-02), então neles
`null` só pode ser "não mexi" e o tipo simples basta — a assimetria da API espelha
a do backend, de propósito.

`Patch.diff(atual, anterior)` é onde a decisão acontece: os dois estados chegam do
`FormControl` idênticos, como `null`, e o que os separa é o valor que o cartão
tinha **quando a tela abriu**. Por isso o controller guarda `_cardOnOpen` e não o
atualiza enquanto a pessoa digita.

**Uma tela para cadastrar e editar, e nenhuma tela de detalhe.** Ganho tem duas
telas para mexer em dinheiro porque reajuste e correção fazem coisas diferentes
com o passado. Cartão não tem passado: trocar o dia de fechamento não reescreve
mês nenhum. Um cartão são cinco campos, então uma tela só de leitura para eles
seria um passo a mais para chegar ao mesmo formulário. O modo vem do id da rota —
`/credit-cards/form` cadastra, `/credit-cards/:id` edita.

**Salvar sem ter mexido em nada fecha a tela, sem requisição.** O `PATCH` de corpo
vazio volta 400 ("Informe ao menos um campo para atualizar"), e prender quem só
abriu e fechou seria absurdo. O controller compara, não acha diferença e devolve
o id como se tivesse salvo — porque, em efeito, salvou.

**O 409 do CAR-07 fica dentro do diálogo de exclusão.** "Este cartão tem gastos
vinculados" é resposta à pergunta que o diálogo fez, e a FK é `RESTRICT`: o cartão
continua lá, na lista de trás, sem ter sido tocado. Rede e 500 sobem para
snackbar; conflito não.

**Dois widgets novos em `core/shared`:** `DayFieldWidget` (dia 1–31 por setas,
circular na virada) e o `Patch` acima. O dia é seletor pela mesma razão da
competência — o 400 do backend para dia inválido chega com a mensagem crua do zod
("Too small: expected number to be >=1"), que ninguém entenderia. Com seletor a
requisição nem sai.

**Testes da fase** (68 no total): `patch_test.dart` (10 casos: os três estados, o
diff nos quatro cruzamentos, e a igualdade por valor que o `verify` exige),
`credit_card_model_test.dart` (7: parse do JSON real com e sem os opcionais,
`dueDate` null sem competência, CAR-03 nos dois sentidos e com dias iguais),
`credit_card_list_controller_test.dart` (9: busca com competência, corrida,
exclusão, e o 409 devolvido sem recarregar), `credit_card_form_controller_test.dart`
(22: cadastro, dígitos opcionais, edição, GET que falha, **oito casos só do corpo
do `PATCH`**, e as recusas do backend), `credit_card_pages_test.dart` (18 de
widget: lista com e sem limite, vazia, erro, diálogo de exclusão com o 409,
formulário nos dois modos, helper do CAR-03, e o "abrir e fechar não manda
requisição"), mais 2 casos novos em `app_router_test.dart` — a corrente da home
até o formulário, e a rota de edição. O primeiro desses dois **ficou vermelho
até a Fase 4**: ele rolava a home atrás da linha "Cartões" que nunca foi
construída. Foi reescrito para entrar pelo menu lateral, que é por onde o
caminho existe.

**O que os testes da fase não cobriam:** o 409 do CAR-07 ao vivo — sem gasto não
havia o que vincular. **Pago na Fase 5**: excluir um cartão com gasto vinculado
devolve `ConflictFailure` com "Cartão possui gastos vinculados", conferido contra
o Docker.

Segue sem prova o caminho de `dispose` do `CreditCardListController` em
produção: no `test_injector` ele é `registerFactory`, mesma divergência que já
existe no `HomeController`.

### Fase 4 — Gastos fixos · ▓▓▓▓▓▓▓▓▓▓ concluída
A primeira fase com dois caminhos de pagamento, e a que fechou o critério da
Fase 3.

- [x] Criar `FIXED` no débito ou no cartão, com categoria opcional
- [x] Editar dados cadastrais (GFX-06), com o `PATCH` parcial
- [x] Reajuste, correção e encerramento — o mesmo motor de vigência de ganhos
- [x] Recorrente vs. mês único (GFX-03)
- [x] O cartão cadastrado aparece como opção no formulário — **critério da
      Fase 3, fechado aqui**
- [x] Item "Gastos" no menu lateral, e a seção "Débito e dinheiro" da home
      virou porta da lista
- [x] **Tela do cartão**: tocar um cartão mostra o que foi lançado nele e a
      fatura do mês

**Pronto quando:** um aluguel reajustado em julho aparece com valor antigo em
junho e novo em julho, no resumo.
→ **Fechado.** Contra o Docker, com o aluguel de R$ 1.200,00 reajustado para
R$ 1.350,00 em julho: `/summary?month=2026-06` devolveu 120000 e
`?month=2026-07` devolveu 135000. O ciclo inteiro foi exercitado pelo
repositório de verdade — cadastro, reajuste, correção, os dois sentidos do
`PATCH`, o 422 de reajuste retroativo, encerramento, listagem e exclusão.

**Quatro decisões desta fase:**

**`amountCents` nulo é o normal, não um erro.** Diferente de ganhos (GAN-10), o
backend **não** escolhe uma vigência quando a busca vem sem `?month`: manda
`amountCents: null` e o histórico completo. A lista de gastos busca sem
competência de propósito — com ela, o backend esconderia o que não é cobrado
neste mês (GFX-10), e um gasto encerrado ficaria inalcançável para consultar ou
apagar. Então o valor exibido sai de `ExpenseModel.amountCentsIn(mês)`, e
`latestAmountCents` cobre o que está fora de qualquer vigência.

**O formulário de edição não tem campo de valor.** Descrição, categoria, forma
de pagamento e cartão não são versionados (GFX-06) e valem para todos os meses;
dinheiro muda por reajuste, correção ou encerramento, e cada um faz uma coisa
diferente com o passado (CONC-11). Um campo "valor" na edição apagaria essa
escolha — seria o "editar" genérico que o backend recusou a existir. Por isso o
`submit` valida só os campos que o modo mostra: em edição, valor e competência
nem estão na tela, e validar o grupo inteiro travaria o salvamento sem ter o que
corrigir.

**Trocar a forma de pagamento é um método, não um `valueChanges` escutado.** A
troca tem dois efeitos que precisam valer no mesmo instante — cartão vira
obrigatório, ou é descartado (GFX-01/GFX-07) — e o stream do reactive_forms
entrega no microtask seguinte. Quem salvasse no mesmo frame da troca veria o
estado anterior. `selectPaymentMethod` faz as duas coisas em sequência, e o
`submit` refaz a sincronização como garantia, para a regra valer mesmo que o
campo tenha sido preenchido por outro caminho.

**A tela do cartão existe agora, e a Fase 3 tinha decidido que não existiria.**
Na época a conta era outra: um cartão eram cinco campos, e uma tela só de leitura
para eles seria um passo a mais no caminho do formulário. Com gasto no cartão
existindo, ela responde o que a lista não responde — *o que eu lancei neste
cartão?* —, então o toque na lista passou a abrir o cartão e a edição virou o
lápis da barra, uma tela adentro. `/credit-cards/:id` é a tela do cartão e
`/credit-cards/:id/edit` a edição, filha dela, para o "voltar" da edição cair no
cartão. A fatura do resumo, na home, virou a segunda porta para o mesmo lugar.

**São três buscas para montar a tela do cartão, e cada uma responde uma pergunta
diferente.** O cartão com `?month` traz o vencimento resolvido (CAR-03); a lista
**sem** competência traz tudo que existe no cartão, inclusive o encerrado; a
lista **com** competência traz o que é cobrado no mês, já com valor. A terceira
não dá para deduzir da segunda — sem competência o `amountCents` vem null, e num
parcelado o valor do mês nem está no `history`, está nas parcelas (GFX-09).
Somar o que dá localmente daria um total que passa a mentir no dia em que
existir parcelado.

**O nome do cartão no detalhe é best-effort.** O gasto traz `creditCardId`, não
o nome, e uma segunda busca só para escrever "Nubank ••••1234" não pode virar
tela de erro: se ela falha, a tela diz só "No cartão" e segue. O gasto já está
montado quando a busca do cartão começa.

**Dois arquivos saíram de ganhos para `core/shared`**, porque a Fase 4 provou
que não eram de ganhos: `AmountVersionModel` (era `IncomeVersionModel`) e
`AmountHistoryCard` (era `IncomeHistoryCard`). Os dois leem o mesmo motor de
vigência do backend, que é compartilhado lá também (`AmountTimeline`,
`shared/http/presenters.ts`). O que **não** foi unificado, de propósito: os
diálogos de reajuste e encerramento, que se repetem em forma entre ganho e gasto
mas falam de coisas diferentes ("recebi um aumento" × "o aluguel subiu"). É a
mesma escolha que o backend fez entre `incomes` e `expenses` — DRY é sobre
duplicar conhecimento, não texto.

**Testes da fase** (82 no total): `expense_model_test.dart` (15: parse do JSON
real com e sem competência, o parcelado que chega com `history` null, o valor
por competência nos dois lados do reajuste, e a diferença entre "encerrado" e
"não é mais cobrado"), `expense_list_controller_test.dart` (5: busca sem
competência, falha, refresh silencioso e a guarda de corrida),
`expense_form_controller_test.dart` (19: cadastro nos dois meios de pagamento, o
cartão obrigatório do GFX-01, a limpeza do GFX-07, categoria vazia virando null,
edição só do que é cadastral, os corpos do `PATCH` e o "abrir e fechar não manda
requisição"), `expense_detail_controller_test.dart` (10: as quatro operações, a
recarga silenciosa depois de cada uma, o 422 devolvido a quem chamou e o nome do
cartão que falha sem derrubar a tela), `expense_pages_test.dart` (20 de widget),
`credit_card_expenses_test.dart` (8: as três buscas, a soma da fatura, a falha
e a tela), mais 3 casos novos em `app_router_test.dart`, 1 no
`home_navigation_test.dart` e 1 no `home_page_test.dart`.

**O que os testes da fase não cobrem:** o formulário não impede cadastrar gasto
no cartão quando não há cartão nenhum — mostra um aviso e deixa o botão salvar
recusar pelo campo obrigatório, que é feio mas correto; e o caminho de `dispose`
do `ExpenseListController` em produção, mesma divergência de registro que já
existe nas outras listas.

O formulário e o detalhe assumiam gasto fixo em todo canto, o que era esperado
enquanto parcelado não tinha tela. **A Fase 5 desfez essa suposição** — o
seletor de tipo e o desvio das operações entraram lá.

### Fase 5 — Gastos parcelados · ▓▓▓▓▓▓▓▓▓▓ concluída
A fase com mais regra de negócio, e a que fez o app aceitar os **dois regimes de
escrita** de gasto.

- [x] Criar `INSTALLMENT` pelo mesmo formulário, com seletor de tipo
- [x] Ver o plano de parcelas, com a do mês em destaque
- [x] Reparcelamento — total e quantidade novos, a partir de um mês
- [x] Quitação antecipada
- [x] As operações de fixo somem em parcelado, e vice-versa (GPR-17)

**Pronto quando:** R$ 100 em 3x mostra 33,34 + 33,33 + 33,33, e reparcelar em
outra quantidade não mexe nas parcelas passadas.
→ **Fechado.** Contra o Docker, pelo repositório de verdade: geladeira de
R$ 3.000 em 10x, reparcelada para R$ 4.000 em 12x a partir de maio — as quatro
primeiras continuaram R$ 300 e as oito novas saíram a R$ 350; quitada a partir
de setembro, sobraram 8 parcelas com a última virando `8/8`. O rateio em si é
do backend e está coberto lá, exaustivamente.

**Quatro decisões desta fase:**

**O tipo é escolhido no cadastro e nunca mais muda.** Fixo guarda dinheiro em
vigência, parcelado em parcela (GFX-09), e trocar o tipo de um gasto existente
seria jogar fora a fonte da verdade dele. O backend nem oferece a operação;
aqui o seletor simplesmente não aparece na edição.

**A validação é por campo, e não pelo grupo.** Os campos do tipo não escolhido
nascem vazios e inválidos — se o `submit` olhasse `form.invalid`, escolher
parcelado travaria o salvamento por causa de um "valor por mês" que nem está na
tela. Cada modo valida a lista de campos que mostra. Foi a mesma escolha já
feita na Fase 4 para a edição, agora com um segundo motivo.

**`amountCentsIn` procura nos dois lugares.** O valor de um mês vem da vigência
num gasto fixo e da parcela num parcelado, e como nenhum gasto tem as duas
listas preenchidas, não há ambiguidade em olhar as duas. O ganho é que a lista,
o tile e o detalhe não perguntam de que tipo é o gasto para saber quanto ele
custa neste mês.

**O selo do tile virou a parcela.** Num parcelado, "3/10" diz ao mesmo tempo que
está em curso e quanto falta — mais do que "Mês único" diria. Como a listagem
não leva `?month`, o `installmentLabel` do backend vem null ali, e o rótulo é
montado do plano: é para isso que o model lê `installments` inteiro.

**Dois diálogos novos, e os dois avisam do que o sistema não faz.** O de
reparcelamento diz que os dois números são **totais da compra**, contando as
parcelas já cobradas — quem digita "12" está dizendo doze no total, não mais
doze — e mostra quantas ficam de fora. O de quitação avisa que **o valor pago na
antecipação não é registrado**: o sistema projeta o que é devido, não concilia o
que foi pago, e quem quiser ver o desembolso precisa lançar um gasto avulso.

**Testes da fase** (17 no total, em `expense_installment_test.dart`): o model
lendo as dez parcelas e o valor por competência, a resposta real de um
reparcelamento provando GPR-08, GPR-10 e GPR-11 de uma vez, o cadastro nos dois
tipos, os campos do tipo não escolhido não travando o salvamento, as duas
operações no controller, e as telas — as ações que somem, o plano listado, os
campos que trocam com o tipo e a prévia de "10x de R$ 300,00".

**O que os testes da fase não cobrem:** o rateio, que é do backend e está
coberto lá com todos os totais de 1 a 400 centavos contra 1 a 24 parcelas —
reimplementá-lo aqui duplicaria conhecimento para provar a mesma coisa duas
vezes.

### Fase 6 — Projeção · ▓▓▓▓▓▓▓▓▓▓ concluída
A primeira tela que não é cadastro — ela não escreve nada. O
`SummaryRepository.getProjection` existia desde a Fase 0 e nunca tinha tido
consumidor.

- [x] Saldo acumulado mês a mês, em gráfico e em lista
- [x] Horizonte configurável: 6, 12 ou 24 meses
- [x] Aviso do primeiro mês no vermelho
- [x] Item "Projeção" no menu lateral

**Três decisões desta fase:**

**O gráfico é desenhado à mão, sem biblioteca.** São barras verticais com uma
linha de zero, num `CustomPainter` de sessenta linhas — sem eixo com escala,
legenda ou interação. Uma dependência de gráfico custaria mais do que isso e
traria o que a tela não usa. Se um dia precisar de zoom, tooltip ou várias
séries, a conta muda e vale reabrir.

**A barra é o acumulado, e não o saldo do mês.** A pergunta da tela é "quanto
vou ter juntado": um mês negativo no meio de uma sequência boa não assusta
ninguém, o acumulado cruzar o zero sim. O saldo do mês continua na lista, em
segundo plano, porque sem ele não dá para saber *por que* o acumulado subiu ou
caiu. E a escala inclui o zero sempre — sem isso, uma sequência toda positiva
desenharia a menor barra colada no chão, dando impressão de mês zerado onde
sobra dinheiro.

**A tela avisa que a conta começa do zero.** O backend acumula a partir de zero,
não do que existe em conta (decisão registrada em `05-resumo-mensal.md`), e sem
essa ressalva o número grande do topo é uma promessa que o app não fez.

**Pronto quando:** a projeção mostra o saldo acumulado dos próximos meses e
avisa quando ele fica negativo.
→ **Fechado.** Conferido contra o Docker nos dois cenários: com os dados atuais
a projeção sobe mês a mês; com um gasto avulso de R$ 50.000,00 em agosto, ela
afunda e sobe de volta sem cruzar o zero dentro do horizonte — e o aviso aponta
o primeiro mês no vermelho, que é o caso em que o último acumulado ainda é
negativo enquanto o saldo mensal já voltou a ser positivo.

**Testes da fase** (13, em `projection_test.dart`): o horizonte inicial e a
troca dele, a busca que não se repete quando a escolha é a mesma, a guarda de
corrida — que aqui pesa mais que nas outras telas, porque a resposta de 24 meses
pode chegar depois da de 6 —, o aviso do mês no vermelho com a projeção real de
uma reforma, e a ressalva do saldo inicial.

**O que os testes da fase não cobrem:** o desenho do gráfico. O `CustomPainter`
é verificado só por existir na árvore; comparar pixel exigiria golden test, que
o projeto ainda não usa em lugar nenhum.

### Fase 7 — Acabamento · ▓▓▓▓▓▓▓▓▓▓ concluída
Levantada item a item em 21/08 contra o código — parte do que estava listado já
tinha entrado com as fases anteriores — e fechada no mesmo dia.

**Já feito, sem ter sido creditado aqui:**

- [x] **Pull-to-refresh em todas as telas** — `RefreshIndicator` em nove views
  (ganhos, gastos, cartões, projeção e os detalhes), incluindo o caso de lista
  vazia, com `AlwaysScrollableScrollPhysics` para o gesto existir sem conteúdo
- [x] **Estados vazios** nas quatro listas e na projeção, com ícone, título e
  uma frase que orienta o próximo passo ("*Comece pelo salário — o resumo do mês
  depende dele*")
- [x] **Erro de backend por tela** — `FailureCardWidget` com `switch` exaustivo
  nos nove tipos de `Failure`, e `isRetryable` decidindo se cabe "Tentar de novo"

**Feito nesta fase:**

- [x] **Tema claro/escuro.** Os dois saem do mesmo seed por `fromSeed`, que
  deriva o esquema inteiro — inclusive os pares `on*`, que são o que garante
  contraste. Segue o sistema (`ThemeMode.system`) em vez de guardar
  preferência: guardar exige armazenamento local, que só chega na Fase 10.

  Duas coisas que só apareceram ao montar a tela no escuro: `Colors.orange`
  fixo em dois lugares — comprometimento acima de 80% e fatura acima de 80% do
  limite — que no escuro vibra e compete com o vermelho do erro, e a elevação
  padrão do card, que no Material 3 **clareia a superfície** e transformaria a
  home num degradê de cinzas. O laranja virou `AppColors.warning`, uma
  `ThemeExtension` com valor por tema; o card perdeu a elevação e ganhou borda.
- [x] **Transição entre estados.** As rotas continuam com a transição padrão
  da plataforma, de propósito (ver abaixo); o que ganhou animação foi a troca
  entre carregando, erro e conteúdo, que antes acontecia no mesmo frame e lia
  como piscada. `StateTransition` em oito telas.
- [x] **Estado vazio extraído** para `EmptyStateWidget`, que embrulha o scroll
  e o `RefreshIndicator` junto — não só o miolo. A lista vazia é justamente
  onde o pull-to-refresh some sem querer, e deixar isso a cargo de quem chama é
  convidar a esquecer: foi o que tinha acontecido na projeção, que era a única
  tela vazia sem o gesto. Agora tem.
- [x] **Identificador trocado** para `com.secontroleai.app`, nos dois: Android
  (`namespace`, `applicationId` e a árvore de pastas do `MainActivity.kt`) e
  **iOS**, que também estava com o do template e que este roadmap não
  mencionava. Conferido no APK compilado, não só no fonte.

**Decidido e fechado:**

- [x] **A máscara de moeda ao vivo não entra.** O campo já tem prefixo `R$ `,
  teclado numérico, filtro de caracteres e formatação ao preencher por código.
  Reformatar enquanto digita briga com a decisão do `reactive_forms` de não
  interromper a digitação, e costuma dar cursor pulando. Reabrir só com
  reclamação concreta de quem usa.
- [x] **O offline global espera a Fase 11.** Por tela já está resolvido com o
  `FailureCardWidget`. Um banner de conectividade agora seria reescrito lá, que
  é onde base local e outbox entram.

**Uma coisa que foi decidida contra o texto original desta fase:** as rotas
continuam com a transição padrão. Trocar por `CustomTransitionPage` **remove o
gesto de voltar deslizando no iOS**, que é fornecido pelo
`CupertinoPageTransition` — seria trocar função por enfeite. O que faltava de
verdade era a transição de estado dentro das telas, e é ela que entrou.

### Fase 8 — Qualidade · ░░░░░░░░░░ não iniciada
Testes de model (parse do JSON real), de repositório (Dio mockado), de
controller (repositório fake) e de widget nas telas principais. `flutter analyze`
sem issue como porta de entrada.


### Fase 9 — Login · ▓▓▓▓▓▓▓▓▓░ em andamento
A **Etapa 7 do backend** ficou pronta em 26/08 e desbloqueou esta fase, que
começou no mesmo dia. Em 27/08 aconteceram três coisas: o login foi provado em
aparelho, a AUT-11 foi retirada — cadastrar virou entrar, e a tela de
"Aguardando aprovação" deixou de existir — e o **GitHub saiu do corte**. O
provedor foi fechado em 25/08 e é **Firebase Auth**; o login é **só pelo
Google** (`expense-tracker-api/docs/specs/08-autenticacao.md`).

**O que já está em pé** (commits `6dfedd5`, `f2d3268` e `255d28b`):

- [x] `firebase_core`, `firebase_auth` e `google_sign_in`, com o app Android
      registrado no projeto `secontroleai`, o `firebase_options.dart` gerado e
      o SHA-1 de **debug** cadastrado
- [x] `main()` assíncrono: `ensureInitialized` e `initializeApp` antes do
      injector
- [x] `AuthRepository` — entrar pelo Google, sair dos dois lados e o ID token.
      Sair só do Firebase deixaria a conta escolhida no Google, e o login
      seguinte entraria sozinho na mesma
- [x] Tela de login com **um** botão, sem campo nenhum
- [x] `AuthInterceptor`: Bearer em toda requisição, e num 401 renova à força e
      repete uma vez
- [x] `redirect` no `go_router`, alimentado pelo `AuthRefresh`
- [x] Botão de sair no menu, com a conta atual embaixo
- [x] **38 testes novos**: 12 no repositório, 8 no controller, 7 na tela, 6 no
      interceptor e 5 no redirect
- [x] **O login provado em aparelho, em 27/08.** A folha do Google abre, a conta
      é escolhida, o token chega ao backend: 401 sem ele, 403 de pendente com
      ele antes da aprovação, 200 depois. Era o único ponto que teste nenhum
      alcança — SHA-1 e `google-services.json` deixaram de ser fé. O 403 do meio
      dessa sequência já não é reproduzível: a regra saiu no mesmo dia
- [x] **Só Google (AUT-02 fechada em 27/08).** O GitHub saiu do corte sem
      nunca ter tido código, e levou junto o deep link, o esquema de URL e o
      fluxo de vinculação da AUT-12. O tratamento do
      `account-exists-with-different-credential` foi removido do
      `auth_repository`: com um provedor, o erro não tem como acontecer
- [x] **Cadastro é acesso (AUT-11 retirada, 27/08).** Quem entra pelo provedor
      entra no app. A tela de "Aguardando aprovação" foi **removida** — não é o
      caminho da exceção, é caminho nenhum. No backend caíram o guard, o
      `PendingApprovalError` e a coluna `approved_at`
      (`009_drop_user_approval.sql`)

**O que falta:**
- [ ] **SHA-1 de release.** Sem ele o login funciona no `flutter run` e falha
      no APK publicado
- [x] **A tela de espera na abertura**, feita em 31/08. O `redirect` não decide
      mais nada enquanto o Firebase não responde: `AuthRefresh` passou a saber
      se o primeiro evento já chegou, e até lá qualquer rota vira `/splash`. O
      destino original vai guardado na query, então abrir o app por link não
      termina na home por acidente
- [ ] **Não há como revogar acesso.** Nem rota, nem coluna: o `UPDATE users SET
      approved_at = NULL` existiu por um dia e foi embora com a `009`. Quem
      entrou, entrou. Apagar a identidade no console do Firebase impede novos
      logins e deixa a linha e os dados no banco — é o mais perto que existe

**Não há mais tela de cadastro**, e é consequência da decisão, não corte de
escopo: quem conduz cadastro, senha e recuperação é o Firebase. Sobra uma tela
de entrar, com um botão.

O que a fase entrega:

- `firebase_core`, `firebase_auth` e `google_sign_in` — e a configuração do
  `google-services.json`, que o `firebase_messaging` da Fase 10 vai reaproveitar
  inteira
- Tela de login com **um** botão — Google —, e a decisão do que ela mostra
  enquanto o SDK responde. Chegou a ser planejada com dois; o GitHub saiu em
  27/08
- O Google é nativo: SDK do aparelho, sem navegador, sem deep link e sem
  esquema de URL para configurar. Essa cauda toda era do GitHub, e foi embora
  com ele
- ~~**O fluxo de vinculação de contas** (`AUT-12`)~~ — **fora do corte com o
  segundo provedor.** Ele existia para o caso de o mesmo e-mail entrar por dois
  caminhos; com um caminho só, `account-exists-with-different-credential` não
  tem como acontecer. Volta junto com o dia em que houver um segundo botão
- Guarda de rota no `go_router`: sem sessão, qualquer rota redireciona para o
  login — e é aqui que o `redirect` do router finalmente ganha uso. Ficou
  alimentado por `authStateChanges()`, e não por `idTokenChanges()`: o que a
  navegação precisa saber é se **há alguém**, e o segundo dispara a cada
  renovação de token, o que faria o `redirect` rodar de hora em hora sem nada
  ter mudado
- O interceptor do Dio mandando `Authorization: Bearer` com o ID token. Nasceu
  **ao lado** do `x-api-key`, como camada com propósito diferente — a chave não
  identificava ninguém, mas descartava varredura automática antes de o servidor
  gastar uma verificação de assinatura. Em 31/08 a chave saiu e o interceptor
  ficou sozinho: o header dele é o único que o app manda
- **401 passa a significar outra coisa.** Hoje quer dizer "a chave do build está
  errada" e a `UnauthorizedFailure` não é retentável de propósito. Com sessão,
  401 passa a ser "o token expirou" — e a resposta certa deixa de ser mostrar
  erro: é pegar um token novo e repetir a requisição, calada, e só cair no login
  quando isso também falhar
- Botão de sair: `signOut()` e pronto
- ~~Tratar o **403 novo** da `AUT-11`~~, que era conta sem acesso liberado. Foi
  feito e desfeito: a regra saiu em 27/08 e o tratamento saiu com ela. O
  raciocínio de então continua valendo para o dia em que existir um 403 de
  verdade — o login **funcionou**, e mandar tentar de novo seria o pior conselho
  possível ali

**Sem armazenamento de token, e essa é a mudança grande.** O SDK do Firebase
guarda a sessão sozinho, em armazenamento seguro da plataforma, e renova o ID
token antes de ele vencer. Cai fora o `flutter_secure_storage`, cai fora guardar
refresh, e **cai fora o interceptor single-flight** — que era a parte
genuinamente difícil desta fase nos dois desenhos anteriores. O interceptor só
chama `getIdToken()` e segue; a fila é problema do SDK.

**A abertura do app teve que ganhar uma espera, e ela existe desde 31/08.** O
`redirect` lê `currentUser` no primeiro build; se o `firebase_auth` ainda não
restaurou a sessão nesse instante, ele lê `null` e manda para o login alguém que
está logado — o `AuthRefresh` corrige um quadro depois, e o que se vê é um
piscar da tela de login.

O conserto não foi adivinhar o tempo do SDK: foi **parar de responder à pergunta
errada**. O `AuthRefresh` passou a distinguir "não há ninguém logado" de "ainda
não sei", e enquanto a segunda for verdade ninguém decide nada — a rota vira
`/splash`, que é um indicador de progresso sem marca e sem texto, porque some
antes de ser lido. Chegado o primeiro evento, a decisão acontece com a resposta
certa em mãos.

**Ele guarda um contador, e não o usuário.** Um signal só notifica quando o
valor muda: com o usuário dentro, o primeiro evento de quem *não* está logado
seria `null` → `null`, mudança nenhuma, e o app ficaria preso na espera para
sempre. O contador sempre muda. E quem sabe quem está logado continua sendo o
repositório — duas verdades sobre isso divergiriam, e a que decide navegação é a
pior das duas para estar errada.

**A decisão saiu de dentro do router.** Virou `rotaParaEstado`, uma função de
quatro entradas em `auth_gate.dart`, com 14 testes cobrindo as combinações. Pelo
router ela só era alcançável com `pumpWidget`, injetor montado e um router
global que guarda estado entre testes — e aí o que falha não diz qual
combinação quebrou. O caminho completo continua coberto por widget test, em
arquivo próprio: o `AuthRefresh` do router é global e assina o primeiro stream
que encontra, então testar a espera exige o primeiro contato com o `appRouter`
acontecendo num isolate só dela.

**Pronto quando:** duas contas diferentes, no mesmo aparelho, veem gastos
diferentes — e nenhuma vê a tag da outra. O token expirando no meio do uso não
aparece na tela: renova e segue.

**O risco de conta duplicada saiu junto com o GitHub.** Ele era concreto: quem
entrasse pelo segundo provedor com e-mail privado chegaria como
`@users.noreply.github.com`, endereço diferente do Google, e viraria um segundo
`uid` com um app vazio — o sintoma de "meus gastos sumiram" sem que nada tivesse
dado errado. Com um provedor, um e-mail é um `uid`. **A única coisa a não fazer
é desligar o "One account per email address" no console do Firebase**: hoje ele
não muda nada, e é por isso mesmo que é fácil desligar sem pensar e só descobrir
no dia do segundo botão.

### Fase 10 — Notificações · ░░░░░░░░░░ não iniciada
Depende da **Etapa 8 do backend** (veja `expense-tracker-api/docs/specs/07-notificacoes.md`),
e não começa antes dela: quem decide *quando* notificar é o servidor.

**Por que não dá para resolver só no app.** Com o app fechado não existe timer
que o sistema garanta — o Android mata alarme exato em Doze e o iOS não executa
código arbitrário em background. Notificação agendada localmente serve para o
que já está na memória do dispositivo e não depende de dado novo; vencimento de
fatura muda quando um gasto é lançado em outro aparelho. Então: **push**, com o
backend decidindo, e notificação local só para exibir o que chega em foreground.

O que a fase entrega:

- `firebase_messaging` para o push e `flutter_local_notifications` para exibir
  em foreground — no foreground o FCM **não** desenha nada sozinho
- Pedido de permissão (iOS sempre; Android 13+ pelo `POST_NOTIFICATIONS`), com o
  app funcionando inteiro sem ela
- Registro do token no backend a cada abertura e a cada `onTokenRefresh`, junto
  com o fuso do aparelho — o servidor agenda em UTC, e "3 dias antes do dia 17"
  só faz sentido no fuso de quem lê
- Handler de background com `@pragma('vm:entry-point')`, que roda numa isolate
  separada e não enxerga o `getIt` do app
- Toque na notificação abre a tela certa — `go_router` já navega por nome, então
  é o payload trazer rota e id
- Tela de preferências: quais notificações, e com quantos dias de antecedência

**Pronto quando:** com o app **fechado**, uma fatura que vence em três dias
chega como notificação, e tocá-la abre o cartão certo.

### Fase 11 — Offline-first · ░░░░░░░░░░ não iniciada
**A última fase, e é de propósito.** O app hoje só funciona conectado: toda tela
pergunta ao backend e mostra `FailureCardWidget` quando ele não responde.

**Por que depois, e não junto.** Offline-first não é um cache que se liga no
fim — é uma **segunda fonte da verdade**, com escrita própria, e cada tela passa
a existir em dois modos. Enquanto o domínio ainda muda a cada fase (a 5 traz
outro regime de escrita para gasto, a 7 traz notificação), escrever cada tela
duas vezes dobra o custo de cada mudança. Fazer por último é pagar uma vez, com
o contrato já parado.

O que a fase entrega:

- **Base local** (drift, provavelmente — SQL tipado e migration versionada), com
  as mesmas tabelas do backend e um `updated_at` por linha
- **Leitura cache-first**: a tela abre com o que está no disco e revalida em
  seguida. O `Result<T, Failure>` já é a costura — a UI não muda, quem muda é o
  repositório, que passa a ter duas fontes
- **Escrita por outbox**: a mutação grava local, entra numa fila e a tela
  responde na hora. Quem esvazia a fila é um sincronizador, com retry
- **Sincronização por delta**, com o backend expondo `?since=` e **soft delete**
  — sem `deleted_at`, um item apagado em outro aparelho ressuscita na próxima
  sincronização

Quatro problemas que esta fase precisa resolver, e que não existem hoje:

**O id deixa de vir do backend.** Hoje o `201` devolve o `id` e o app o usa; um
item criado offline precisa de id **antes** de existir no servidor. Isso obriga
o app a gerar UUID e o backend a aceitá-lo no `POST`, de forma idempotente —
reenviar a mesma criação não pode criar duas.

**Vigência não aceita last-write-wins.** Dois aparelhos reajustando o mesmo
gasto geram vigências que se sobrepõem, e a constraint `EXCLUDE USING gist`
recusa a segunda — corretamente. "O último a escrever ganha" resolveria um
`UPDATE` de campo solto, não uma linha do tempo de dinheiro. Precisa de política
explícita, provavelmente rejeitar e mostrar o conflito a quem escreveu.

**O resumo mensal é derivado, e o app não sabe derivá-lo.** `buildMonthlySummary`
mora no backend, e portá-lo para o Dart duplicaria conhecimento — o que este
projeto vem evitando de propósito. A saída barata é **cachear a resposta por
competência** e marcar quando ela é velha; a cara é reimplementar a regra. A
barata é a certa até prova em contrário.

**"Atualizado quando?" vira informação de tela.** Um número velho sem aviso é
pior que tela de erro: quem vê R$ 2.544,10 de saldo assume que é de agora. Cada
tela que lê do cache precisa dizer de quando ele é.

**Pronto quando:** com o Docker desligado, o app abre, mostra o mês com o aviso
de que está desatualizado, aceita cadastrar um gasto, e ao religar o backend o
gasto aparece lá sem duplicar.

---

## Armadilhas já mapeadas

Coisas que descobri conferindo os pacotes e o backend, e que custam tempo se
forem encontradas no meio da implementação:

- **`Watch` do signals está deprecado na 7.1.0.** O recomendado agora é
  `SignalBuilder`. Muito tutorial na internet ainda ensina `Watch`.
- **`google_sign_in` 7.x reescreveu a API.** Não existe mais
  `GoogleSignIn().signIn()`: agora é `GoogleSignIn.instance.initialize()` e
  depois `authenticate()`, e o `GoogleSignIn` é singleton de **construtor
  privado** — não dá para forjá-lo em teste, o que obriga um port no meio.
  Quase todo exemplo que se acha é da v6 e não compila.
- **Erro de sintaxe apontando para dentro do `.pub-cache` quase nunca é seu
  código.** Em 26/08 toda a suíte parou de *carregar* por causa de um `a` solto
  no começo da primeira linha de `multiple_result-5.3.0/lib/src/result.dart` —
  tecla perdida com o arquivo do pacote aberto no editor, o que é fácil de
  fazer dando ctrl+clique num tipo. Apagar o pacote do cache e rodar
  `flutter pub get` de novo resolve.
- **Método abstrato com parâmetro nomeado precisa declarar o valor padrão.**
  `Future<String?> idToken({bool forceRefresh})` na interface compila, mas
  chamar `idToken()` pelo tipo da interface **não passa** o argumento — e um
  duplo de teste vê uma invocação sem ele em vez de uma com `false`. O padrão
  tem que estar na declaração, não só na implementação.
- **Reexecutar uma requisição de dentro do `onError` de um `QueuedInterceptor`
  trava.** A fila está ocupada justamente por quem está esperando. E, mesmo com
  `Interceptor` comum, o `dio.fetch` passa pelo `onRequest` outra vez — sem uma
  marca na requisição, ele sobrescreve o token recém-renovado pelo antigo, e a
  repetição leva exatamente a credencial que o servidor acabou de recusar.
- **`Error` do `multiple_result` sombreia o `Error` do `dart:core`.** Ao importar
  o pacote num arquivo que também mexe com erros nativos, use prefixo no import.
- **No emulador Android, `localhost` é o emulador, não a sua máquina.** O backend
  em Docker fica em `http://10.0.2.2:3333`. Em device físico, nem um nem outro —
  precisa do IP da máquina na rede local.
- **O IP da rede local vive em dois arquivos, e os dois precisam andar juntos:**
  `AppConfig._defaultBaseUrl` e `network_security_config.xml`, que autoriza HTTP
  sem TLS para aquele host. Atualizar só um deixa o app quebrado do mesmo jeito.
  É DHCP: em 21/08 a rede trocou de sub-rede e o app passou a pedir um endereço
  onde não havia ninguém. **Timeout, neste app, quase sempre é endereço errado,
  não servidor lento** — no simulador iOS,
  `--dart-define=API_BASE_URL=http://localhost:3333` não depende de DHCP e evita
  o problema de vez.
- **Tag arquivada precisa entrar no seletor ao editar um gasto antigo.** O
  seletor pede só as ativas, mas um gasto pode apontar para uma tag arquivada
  depois de ele ter sido criado. `DropdownButtonFormField` com valor sem item
  correspondente é **assertion do Flutter**, não campo vazio — a tela quebra em
  vez de abrir em branco. O `ExpenseFormController` acrescenta a tag do gasto à
  lista quando ela não está lá.
- **Dobrê de repositório que ignora filtro esconde bug.** O stub de `/tags` só
  passou a valer quando começou a respeitar `includeArchived` como o backend
  respeita: devolvendo tudo sempre, ele nunca pegaria o seletor oferecendo tag
  aposentada.
- **`/summary` recebe o mês por query string, não por path.** `/summary/2026-08`
  responde 404.
- **`amountCents`, `history` e `installments` são nulos conforme o tipo.** Ler o
  campo errado dá `null` silencioso, não erro.
- ~~**O package Android é `app.b4a.mangatrix.se_controle_ai`**~~ — **resolvido
  em 21/08:** virou `com.secontroleai.app`. O iOS estava com o mesmo problema e
  não constava aqui — vale a lição de que identificador de template costuma
  estar nos **dois** lados.
- **Elevação de card clareia a superfície no tema escuro.** É do Material 3, não
  bug: `surfaceTint` sobe com a elevação. Numa tela que empilha card sobre
  fundo, isso vira degradê de cinzas. O `AppTheme` zera a elevação e usa borda.
- **`AnimatedSwitcher` sem chave não anima nada** — nem entre tipos diferentes
  de widget. Sem `key`, ele trata o filho novo como o mesmo de antes, e a
  transição some **em silêncio**, sem erro nenhum. E chavear pelo tipo do
  widget também engana: `Loading` e `Failed` renderizam os dois um `Center`.
  Quem sabe que o estado mudou é o `ViewState`, por isso o `StateTransition`
  pede um `stateKey`.
- **O backend não tem autenticação nem noção de usuário.** Hoje é single-user, e
  o que o protege na internet é a `x-api-key`. É a Etapa 7 de lá e a Fase 9
  daqui — decidida, especificada e não iniciada.

Descobertas já na pele, implementando a Fase 0:

- **`DioExceptionType.transformTimeout` chegou no dio 5.11.** Um `switch`
  exaustivo sobre esse enum escrito com base em exemplo antigo não compila.
- **`logPrint` do `LogInterceptor` recebe `Object`, e `debugPrint` recebe
  `String?`.** Passar `logPrint: debugPrint` não compila; use
  `logPrint: (line) => debugPrint('$line')`. (Histórico: o `dio_factory` usa
  `PrettyDioLogger` hoje, que já tem o próprio `logPrint`.)
- **`AppConfig` importa `dart:io` para decidir o baseUrl por plataforma, e isso
  não compila para web.** O único device disponível na máquina hoje é o Chrome,
  então rodar no navegador exige trocar por `kIsWeb` + import condicional.
- **Arredondar não conserta ponto flutuante, só reduz o dano.** `0.145` chega
  como `0.1449999...` e `fromReais` devolve 14 centavos, não 15. Entrada de
  usuário deve usar `Money.tryParse`, que lê os dígitos do texto e nunca passa
  por `double`.

Descobertas depois, mexendo na infra e nos models:

- **O dio não remove parâmetro de query nulo.** `{'month': null}` sai como
  `?month` — chave pelada, sem `=`. O Express entrega isso ao zod como string
  vazia, e os schemas do backend são `optional()`: aceitam a **ausência** e
  recusam o vazio. Logo, `GET /incomes` sem mês voltava 400. A limpeza mora no
  `ApiClient` e não nos repositórios, porque a armadilha é do transporte.
- **Teste cujo nome descreve a intenção e a asserção não a verifica é pior que
  teste nenhum.** O caso "parâmetro nulo é removido" existia desde a Fase 0 e
  passava — ele procurava `month=&` e `month=1`, e a URI real era `?month&…`.
  Ficou verde por dois dias afirmando um comportamento que nunca existiu, e o
  bug só apareceu no dispositivo, na primeira tela que passava nulo de verdade.
  Asserção sobre URL agora é sobre `uri.queryParameters` e `uri.hasQuery`, não
  sobre pedaço de string.
- **Retorno `dynamic` esconde erro do analyzer.** `ApiClient.get` devolve
  `Future<dynamic>`, então esquecer o `.data` passa batido no `flutter analyze` e
  só aparece como `TypeError` em runtime — ou no teste, que foi o que aconteceu.
  Se um dia o client ganhar tipo de retorno mais estreito, ou um wrapper próprio
  no lugar do `Response` do Dio, esse tipo de esquecimento vira erro de
  compilação.
- **Teste com fake não protege a camada que o fake substitui.** Os 59 testes da
  Fase 1 seguiram verdes com o `ApiClient` quebrado, porque todos entram pelo
  `FakeSummaryRepository`. Quem guarda essa fronteira é `api_client_test.dart`,
  com `HttpClientAdapter` trocado — vale manter esse padrão para cada camada
  nova de infra.
- **`PrettyDioLogger` só imprime a URI quando o erro é `badResponse`.** Em
  timeout, `connectionError`, `cancel` e `badCertificate` ele imprime só
  `DioError ║ <type>` e `err.message` — e as mensagens padrão de timeout do dio
  não contêm a URL. Ou seja, justamente no caso "backend fora do ar" ou
  "`localhost` em vez de `10.0.2.2`" o log não diz qual rota falhou. Um
  `Interceptor` de três linhas no `onError` cobre isso, se voltar a incomodar.
- **Um model por arquivo e sem barrel.** Renomear ou mover uma classe de model
  quebra o import de todo consumidor de uma vez (foram 48 issues do analyzer numa
  troca de dois nomes). O analyzer aponta cada um, mas conte com o passo de
  ajustar imports como parte do rename, não como surpresa.
- **`dart format` reclama depois de rename por `sed`.** Nome mais longo estoura
  as 80 colunas e o formatter reescreve o arquivo. Rodar `dart format` nos
  arquivos tocados evita diff de formatação misturado com diff de conteúdo.
Descobertas implementando a Fase 2:

- **No go_router, rota fixa vem antes de rota com parâmetro.** `form` declarado
  depois de `:id` vira um detalhe com id `"form"` — o casamento é por ordem, e
  `:id` aceita qualquer coisa.
- **`Month.label` capitaliza**, e no meio de uma frase isso lê como erro de
  digitação: "Janeiro 2026 a Outubro 2026". Por isso existe `Month.periodLabel`,
  que põe o segundo mês em minúscula e trata os três casos (aberto, fechado, mês
  único) num lugar só.
- **`registerFactoryParam` é o registro de quem precisa de argumento.** O
  controller de detalhe não existe sem o id do ganho; `getIt<T>(param1: id)` é
  como a página pede.
- **Ícone repetido quebra `find.byIcon`.** O chevron novo no cabeçalho da seção
  de ganhos deixou dois `chevron_right` na home, e o teste de navegação de mês
  passou a achar dois. `find.descendant(of: find.byType(AppBar), ...)` é mais
  preciso do que era antes — o teste melhorou junto.
- **Teste escrito depois do código confirma o bug em vez de achá-lo.** A primeira
  versão da lista marcava todo ganho avulso como "Encerrado", e o teste que eu
  escrevi afirmava exatamente isso — com uma fixture de dezembro, cujo resultado
  ainda por cima dependia do mês em que o teste rodasse. Fixture de tempo agora é
  função (`singleMonthIncomeJson(month:)`), com o mês relativo ao corrente.
- **Fake que só devolve resposta não testa ganhos.** Reajuste e correção
  produzem o mesmo `Success`; o que os distingue é **o que foi enviado** — daí o
  `verify(() => repository.adjust('income-1', amountCents: 550000,
  effectiveFrom: '2026-11'))`, que é a asserção que os separa.
- **Mock em vez de fake escrito à mão** (mocktail, desde 18/08). O que mudou na
  prática: `repository.adjustments.single` virou `verify(...)` com os argumentos
  nomeados no lugar, e a asserção passou a dizer qual chamada era esperada em vez
  de comparar um `Map`. Três detalhes que custam tempo:
  `verify` **consome** o que foi gravado — chamar duas vezes no mesmo teste
  devolve vazio na segunda; `clearInteractions(mock)` é o que zera o histórico
  antes de um `verifyNever`, no lugar do antigo `.clear()` numa lista; e `any()`
  de tipo não nulo exige `registerFallbackValue` num `setUpAll` — é o caso do
  `RequestOptions` no teste do `ApiClient`.
- **`ControlValueAccessor` avisa o campo por stream.** Testar que digitar não é
  reformatado exige `await Future.delayed(Duration.zero)` depois do
  `updateModel` — sem isso a lista de avisos está vazia por atraso, e o teste
  passa sem provar nada.
- **`Validators.required` do reactive_forms já recusa string em branco**, então
  não precisa de validador próprio para `'   '`. O `trim()` no envio continua,
  porque espaço nas pontas de uma descrição válida ainda é sujeira.
- **Stub padrão em um lugar só.** `mocks.dart` guarda `summaryRepositoryMock()` e
  `incomeRepositoryMock()` já respondendo o caso feliz, e os `stubX(...)` para o
  teste sobrescrever o que importa. Sem isso, cada teste repetiria cinco `when`
  antes da primeira asserção.

- **`BaseController` chama `onInit()` no construtor, e o `onInit` do
  `HomeController` é `async`.** Construir já dispara `load()`, e ninguém tem como
  aguardar essa primeira busca — o `await` de dentro não é observável de fora. O
  `home_controller_test` depende disso: como o fake responde sem latência real, as
  microtasks drenam entre o `setUp` e o corpo do teste, e o estado já chega
  `Loaded`. Com qualquer atraso de verdade essa garantia cai — é o que o próprio
  teste demonstra no caso com `delay`, que precisa de `await`.

## Decisões abertas

1. ~~**Autenticação e multi-usuário**~~ — **resolvida em 21/08: entra, e é a
   próxima.** Multiusuário de verdade: cada pessoa se cadastra e vê só o que é
   seu. Vira a **Etapa 7 do backend** e a **Fase 9 daqui**.

   Entra cedo, e não no fim, porque obriga toda tabela a ganhar `user_id` e toda
   consulta a filtrar por dono — feita agora são 8 tabelas, feita depois de
   notificações e offline seriam 14, mais o job e o delta reescritos.

   **Provedor fechado em 25/08: Firebase Auth. Só o Google desde 27/08.** O
   caminho até aqui passou por senha com token de vida longa e por senha com
   refresh rotativo; os dois caíram quando ficou claro que o `firebase-admin`
   entra no backend pelo FCM da Fase 10 de qualquer jeito, e que
   `verifyIdToken()` vem no mesmo pacote. Autenticação passou a custar perto de
   zero em dependência nova.

   O que isso apaga daqui: senha, tela de cadastro, armazenamento de token e o
   interceptor single-flight. O que isso custa: identidade e push dependendo do
   mesmo projeto do Firebase, e o logout valendo só depois de o token expirar —
   até uma hora (`AUT-08`).

   A **Apple ficou fora**: exige anuidade paga para ser configurada e, sem build
   de iOS, não alcançaria ninguém que o Google já não alcance. Volta quando
   houver App Store, onde é requisito de aprovação.

   **Em 26/08 saiu do papel** com o Google sozinho, e em **27/08 o GitHub saiu
   do corte de vez**. O que ele acrescentava era alcance quase nulo num app
   Android, onde a conta Google já está no aparelho; o que ele cobrava era deep
   link, esquema de URL, e-mail instável e o **fluxo de vinculação** da `AUT-12`
   inteiro — que só existia porque haveria um segundo provedor. Um provedor
   apaga os três problemas de uma vez, e o tratamento do
   `account-exists-with-different-credential` foi removido do app junto.
2. ~~**Offline**~~ — **resolvido em 19/08: entra, mas por último.** Vira a
   **Fase 11**, depois de o app estar pronto. O motivo de não ser agora está lá;
   o resumo é que offline-first não é um cache que se liga no fim, é uma segunda
   fonte da verdade — e enquanto o domínio ainda muda a cada fase, cada tela
   nova precisaria ser escrita duas vezes.
3. ~~**`intl`**~~ — **resolvido em 19/08: não entra.** Moeda já é `Money`, e data
   passou a ser `IsoDate`, as duas por corte de string e sem `DateTime` no
   caminho. É a mesma razão do `Month`: `DateTime` carrega fuso, e fuso é o que
   faz uma data andar um dia para trás. Reabrir isso só se aparecer localização
   de verdade — mais de um idioma na tela.
4. ~~**Onde o backend vai rodar**~~ — **resolvido em 21/08: hospedado.** Está no
   ar em `https://secontroleai.duckdns.org`, numa VPS do Google Cloud com Caddy
   e HTTPS automático. O Docker local continua sendo o ambiente de
   desenvolvimento; o que mudou é que existe um endereço estável para o app
   apontar.

   **Em 30/08 a configuração de build virou arquivo por ambiente.** Antes o
   endereço e a chave iam soltos na linha de comando:

   ```
   flutter build apk --dart-define=API_BASE_URL=... --dart-define=API_KEY=...
   ```

   Passou a ser:

   ```
   flutter run       --dart-define-from-file=env/dev.json
   flutter build apk --dart-define-from-file=env/prod.json --release
   ```

   `env/*.json` fica fora do git e `env/*.example.json` vai junto. O motivo não
   foi estética: o comando solto é longo, some no histórico e é fácil de rodar
   pela metade. Saiu um APK apontando para a rede local em vez de produção, e
   só apareceu abrindo o binário com `strings` — o build não tinha como avisar,
   porque `--dart-define` ausente é um caso válido, não um erro.

   Isso também aposenta o IP de rede fixo no `AppConfig`: quem troca de máquina
   edita o `env/dev.json`, não o código.

5. ~~**A `API_KEY` ainda faz sentido para o app?**~~ — **resolvida em 31/08:
   não. Foi retirada dos dois lados.**

   Ela nasceu na Etapa 7 do backend, antes da autenticação, quando a API não
   tinha como saber quem estava chamando. Com toda rota exigindo token do
   Firebase e resolvendo o dono da requisição, virou uma segunda tranca, mais
   fraca, na mesma porta.

   **O que decidiu não foi a redundância, foi ela não ser segredo.** Num cliente
   distribuído a chave fica em texto dentro do APK, e `strings -a
   app-release.apk` a encontra — tirar o valor do git protegia o repositório,
   nunca quem tem o aplicativo. Era uma string só, igual em todos os aparelhos,
   sem validade e sem dizer quem era. O token é por pessoa, expira em uma hora e
   é verificado por assinatura.

   **O que se perdeu é medível e pequeno:** requisição sem credencial passou a
   custar uma verificação de JWT em vez de uma comparação de hash. As duas são
   locais — o `verifyIdToken` não vai à rede, e o banco só é tocado depois de o
   token valer —, então o que a chave descartava era ciclo de CPU, não consulta
   ao Postgres.

   Saíram: o `apiKeyGuard` e seus 7 testes, a variável dos dois compose e dos
   dois `.env.example`, o header do `dio_factory`, a constante do `AppConfig` e
   o campo dos `env/*.example.json`. **Quem faz esse papel direito é o Firebase
   App Check**, que atesta o app pelo Play Integrity sem embutir segredo no
   binário — e que só vale a pena quando houver track interno na Play, porque a
   atestação exige um build que o Google reconheça.

6. ~~**O app é fechado ou aberto?**~~ — **resolvida em 31/08: aberto.** Quem
   quiser entra, conectando com a conta Google. Não há allowlist, não há
   convite, não há aprovação — a `AUT-11` já tinha caído em 27/08, e isto
   confirma a direção em vez de reabrir o assunto.

   **A defesa deixa de ser impedir e passa a ser observar e limitar**, e isso
   troca a ordem do que falta fazer:

   - **Limite de taxa** vira o primeiro item, e em duas dimensões: por IP,
     contra quem nem token tem, e por `uid`, contra o usuário autenticado que se
     comporta mal. Só por IP não serve num app de celular, onde o endereço muda
     de torre em torre.
   - **Aviso de conta nova** deixa de ser conforto e vira o único sinal de que
     alguém entrou. Sem ele, só se descobre consultando a tabela.
   - **Backup do Postgres** muda de natureza: os dados deixam de ser só seus.

   **E aparecem três obrigações que não existiam com o app fechado**, todas com
   prazo dado pela Play:

   - **Exclusão de conta.** A política do Google Play obriga todo app que cria
     conta a oferecer exclusão, dentro do app **e** por um link na web
     acessível sem instalar. Hoje não existe rota, e as FKs são `ON DELETE
     RESTRICT` em 8 tabelas — é spec nova, com ordem de remoção definida.
   - **Política de privacidade e formulário de Data Safety**, porque o app
     coleta e-mail e nome pelo Google. A página é estática, o Caddy serve.
   - **Quota ou, no mínimo, alarme de disco.** A VPS é pequena e nada hoje
     limita quanto cada pessoa escreve.

   A publicação na Play está a uns 6 meses, então nada disso é para agora — mas
   a exclusão de conta encosta em todas as tabelas, e é a que menos aceita ser
   deixada para o fim.
