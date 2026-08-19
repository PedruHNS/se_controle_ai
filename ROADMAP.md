# Roadmap — se_controle_ai

App Flutter do controle de gastos, cliente da API `expense-tracker-api`
(Node + Express + Postgres, rodando em Docker na mesma máquina).

## Onde estamos

*Atualizado em 19/08/2026.*

Flutter 3.44.9 · Dart 3.12.2 · **Fases 0 a 3 concluídas** · a home mostra o
resumo do mês, ganhos tem CRUD completo com reajuste, correção e encerramento, e
cartões tem CRUD com a edição parcial do CAR-08.

`flutter analyze` sem issue · **244 testes, todos passando** · ganhos e cartões
verificados contra o backend real em Docker, incluindo a recusa de 422 e as duas
direções do `PATCH`.

Em 19/08, antes de abrir a Fase 3, foram fechadas duas dívidas que a fase nova
ia copiar: a guarda de corrida existia só no `HomeController` (ver a convenção
abaixo) e o `app_router_test` cobria um botão que a home não tem. No mesmo dia o
atalho de voltar ao mês atual saiu do `bottom` do AppBar, onde empurrava o nome
do mês para fora da barra.

As seis libs estão em uso:

| Lib | Versão | Papel no app |
|---|---|---|
| `dio` | ^5.11.0 | Cliente HTTP: baseUrl, timeouts, interceptors |
| `multiple_result` | ^5.3.0 | `Result<Sucesso, Falha>` — erro como retorno, não exceção |
| `get_it` | ^9.2.1 | Service locator: Dio, ApiClient, repositórios, controllers |
| `go_router` | ^17.5.0 | Navegação declarativa por rota nomeada + deep link |
| `signals` | ^7.1.0 | Estado reativo: `signal` no controller, `SignalBuilder` na view |
| `pretty_dio_logger` | ^1.4.0 | Log de requisição/resposta em debug, só quando `AppConfig.logHttp` |
| `reactive_forms` | 18.2.2 | Campos, validação e erro de formulário como estado, não como widget |
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

### O que já existe em `lib/`

| Arquivo | O que faz |
|---|---|
| `main.dart` · `app.dart` | Entrada: injector antes do `runApp`, MaterialApp.router |
| `core/config/app_config.dart` | baseUrl por plataforma + `--dart-define=API_BASE_URL`, timeouts, `logHttp` |
| `core/network/dio_factory.dart` | Monta o Dio: BaseOptions, `PrettyDioLogger` quando `logHttp` |
| `core/errors/app_exception.dart` | O que a infra **lança** — técnico: status, código, causa, stack |
| `core/network/exception_mapper.dart` | Único lugar que conhece `DioException` → `AppException` |
| `core/errors/failure.dart` | O que a UI **recebe** — `Failure.fromException` traduz para o usuário |
| `core/network/api_client.dart` | Fala HTTP: devolve o `Response` e **lança** `AppException` |
| `core/di/injector.dart` | Registro no get_it: Dio, ApiClient, repositório, controller |
| `core/router/app_routes.dart` | Nomes e caminhos de rota centralizados |
| `core/router/app_router.dart` | Instância do GoRouter + tela de 404 |
| `core/shared/view_state.dart` | `Loading` / `Loaded` / `Failed` para a view dar switch exaustivo |
| `core/shared/patch.dart` | `Patch<T>`: os três estados de um campo de `PATCH` — `keep`, `clear`, `to` |
| `core/shared/widgets/failure_card_widget.dart` | Card de erro único, com ícone e título por tipo de `Failure` |
| `core/shared/forms/money_value_accessor.dart` | Ponte entre `FormControl<int>` em centavos e o texto do campo |
| `core/shared/widgets/money_field_widget.dart` | `ReactiveTextField<int>` de dinheiro, com as mensagens de erro do valor |
| `core/shared/widgets/month_field_widget.dart` | `ReactiveFormField<String>`: competência por setas, com piso (`minMonth`) para travar o que a regra recusaria |
| `core/shared/widgets/day_field_widget.dart` | `ReactiveFormField<int>`: dia 1–31 por setas, circular na virada |
| `core/utils/base_controller.dart` | Ciclo de vida do controller: `onInit`, `onReady`, `dispose`, com log |
| `core/utils/money.dart` | Centavos ↔ real: `format`, `formatSigned`, `formatCompact`, `tryParse` |
| `core/utils/month.dart` | Competência `YYYY-MM`: label, aritmética, limites do backend |
| `core/utils/iso_date.dart` | Data `YYYY-MM-DD` → `17/08` ou `17/08/2026`, por corte de string |
| `data/models/monthly_summary_model.dart` | `MonthlySummaryModel` — a resposta de `/summary` inteira |
| `data/models/summary_line_item_model.dart` | `SummaryLineItemModel` — a linha usada em ganho, débito e fatura |
| `data/models/debit_group_model.dart` | `DebitGroupModel` — total + itens do débito |
| `data/models/credit_card_invoice_model.dart` | `CreditCardInvoiceModel` — fatura do mês, com `limitUsage` |
| `data/models/month_projection_model.dart` | `MonthProjectionModel` — um mês de `/summary/projection` |
| `data/repositories/summary_repository.dart` | Interface + impl de `/summary` e `/summary/projection` |
| `features/home/controller/home_controller.dart` | Estado do resumo com signals — **é o molde a copiar** |
| `features/home/view/home_page.dart` | A tela: navegação de mês, `switch` no `ViewState`, pull-to-refresh |
| `features/home/widgets/` | `BalanceCard`, `SummarySection`, `CreditCardInvoiceCard`, `LineItemTile` |
| `data/models/income_model.dart` · `income_version_model.dart` | O ganho e suas vigências |
| `data/repositories/income_repository.dart` | As sete rotas de `/incomes`, com reajuste e correção separados |
| `features/incomes/controller/` | `IncomeListController`, `IncomeFormController`, `IncomeDetailController` |
| `features/incomes/view/` | Lista, formulário e detalhe |
| `features/incomes/widgets/` | `IncomeTile`, `IncomeHistoryCard`, e os diálogos de valor e encerramento |
| `data/models/credit_card_model.dart` | `CreditCardModel` — o cartão do CRUD, **não** a fatura do resumo |
| `data/repositories/credit_card_repository.dart` | As cinco rotas de `/credit-cards`, com o `PATCH` do CAR-08 |
| `features/credit_cards/controller/` | `CreditCardListController` (lista + exclusão), `CreditCardFormController` (cadastro + edição) |
| `features/credit_cards/view/` | Lista e formulário; não há tela de detalhe |
| `features/credit_cards/widgets/` | `CreditCardTile` |

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
| `core/utils/iso_date_test.dart` | 6 casos do formato de data, incluindo entrada fora do formato |
| `fixtures/credit_card_fixture.dart` | JSON real de `/credit-cards`: cartão completo, cartão sem os opcionais, e sem competência |
| `core/shared/patch_test.dart` | Os três estados do `Patch` e o `diff` que decide entre eles |

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
  O `_serializationFailure` do `SummaryRepositoryImpl` embala o erro num
  `SerializationException` e devolve como valor. Foi essa rede que transformou a
  regressão do `ApiClient` em tela de erro em vez de tela branca — útil, e também
  o motivo de ela ter passado despercebida por um tempo.

Cada nível tem função distinta: o mapper **classifica** (qual falha técnica foi),
o `Failure` **traduz** (o que o usuário lê). É por isso que um 500 com
`TypeError: x is not a function` mostra "O servidor falhou ao processar" na tela
e guarda o stack do Node em `failure.exception`, para log.

---

## O contrato do backend

Toda a superfície que o app tem para consumir. Dinheiro **sempre em centavos
(int)**; competência **sempre string `YYYY-MM`**.

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
| POST | `/incomes` | `{description, amountCents, startMonth}` |
| GET | `/incomes?month=` · `/incomes/:id?month=` | `amountCents` = valor vigente no mês |
| POST | `/incomes/:id/adjustments` | Aumento: preserva os meses anteriores |
| PATCH | `/incomes/:id/amount` | Correção: o valor estava errado desde o início |
| POST | `/incomes/:id/closure` | `{lastMonth}` — parei de receber |
| DELETE | `/incomes/:id` | |

**Reajuste e correção são operações diferentes** e a UI precisa deixar isso
explícito — não são dois caminhos para "editar valor".

### Cartões
| Método | Rota |
|---|---|
| POST · GET · GET/:id · PATCH/:id · DELETE/:id | `/credit-cards` (`?month=` resolve `dueDate`) |

### Gastos
| Método | Rota | Semântica |
|---|---|---|
| POST | `/expenses` | Discriminado por `type`: `FIXED` ou `INSTALLMENT` |
| GET | `/expenses?month=&type=&paymentMethod=&creditCardId=` | Filtros combináveis |
| GET | `/expenses/:id?month=` | |
| PATCH | `/expenses/:id` | Só descrição/categoria/forma de pagamento |
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
| ░░░░░░░░░░ | Fases 4 a 8 — não iniciadas |

**Próximo passo: Fase 4 — Gastos fixos.** É a primeira fase com dois caminhos de
pagamento (débito e cartão), e a que finalmente fecha o critério da Fase 3: o
cartão cadastrado precisa aparecer como opção no formulário de gasto.

O que já está pronto para ela copiar: o `CreditCardRepository.list` alimenta o
seletor de cartão; `Patch<T>` resolve o `PATCH` parcial, que em gastos é ainda
mais restrito (só descrição, categoria e forma de pagamento); e o par
reajuste/correção de ganhos é o molde do dinheiro com vigência, que `FIXED`
repete.

Duas armadilhas que a Fase 4 herda:

**`FIXED` e `INSTALLMENT` não compartilham operação de dinheiro.** O campo do
outro tipo vem `null`, e isso tem que virar duas telas de edição, não uma com
ifs. Vale reler a seção do contrato antes de começar.

**O 409 do CAR-07 nunca foi exercitado contra o backend**, porque excluir cartão
só é recusado quando há gasto vinculado — e gasto não existia. O caminho de
código está pronto e coberto por mock; a primeira chance de conferir ao vivo é
depois do primeiro gasto no cartão.

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
- [x] Linha "Cartões" na home — a única porta para o cadastro

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
até o formulário, e a rota de edição.

**O que os testes da fase não cobrem:** o 409 do CAR-07 ao vivo (não há gasto para
vincular) e o caminho de `dispose` do `CreditCardListController` em produção — no
`test_injector` ele é `registerFactory`, mesma divergência que já existe no
`HomeController`.

### Fase 4 — Gastos fixos · ░░░░░░░░░░ não iniciada
- Criar `FIXED` (débito ou cartão), editar detalhes
- Reajuste com vigência, correção, encerramento
- Recorrente vs. mês único (`recurring`)

**Pronto quando:** um aluguel reajustado em julho aparece com valor antigo em
junho e novo em julho, no resumo.

### Fase 5 — Gastos parcelados · ░░░░░░░░░░ não iniciada
A fase com mais regra de negócio — vale deixar para depois de o padrão estar firme.

- Criar `INSTALLMENT`, ver as parcelas geradas
- Reparcelamento (corta no mês corrente, numeração continua)
- Quitação antecipada (`settlement`)

**Pronto quando:** R$ 100 em 3x mostra 33,34 + 33,33 + 33,33, e reparcelar em
outra quantidade não mexe nas parcelas passadas.

### Fase 6 — Projeção · ░░░░░░░░░░ não iniciada
- `GET /summary/projection` como gráfico ou lista de saldo acumulado
- Horizonte configurável

### Fase 7 — Acabamento · ░░░░░░░░░░ não iniciada
Tema claro/escuro, máscara de moeda no input, estados vazios com ilustração,
pull-to-refresh, animações de transição, tratamento de "backend offline".

### Fase 8 — Qualidade · ░░░░░░░░░░ não iniciada
Testes de model (parse do JSON real), de repositório (Dio mockado), de
controller (repositório fake) e de widget nas telas principais. `flutter analyze`
sem issue como porta de entrada.

---

## Armadilhas já mapeadas

Coisas que descobri conferindo os pacotes e o backend, e que custam tempo se
forem encontradas no meio da implementação:

- **`Watch` do signals está deprecado na 7.1.0.** O recomendado agora é
  `SignalBuilder`. Muito tutorial na internet ainda ensina `Watch`.
- **`Error` do `multiple_result` sombreia o `Error` do `dart:core`.** Ao importar
  o pacote num arquivo que também mexe com erros nativos, use prefixo no import.
- **No emulador Android, `localhost` é o emulador, não a sua máquina.** O backend
  em Docker fica em `http://10.0.2.2:3333`. Em device físico, nem um nem outro —
  precisa do IP da máquina na rede local.
- **`/summary` recebe o mês por query string, não por path.** `/summary/2026-08`
  responde 404.
- **`amountCents`, `history` e `installments` são nulos conforme o tipo.** Ler o
  campo errado dá `null` silencioso, não erro.
- **O package Android é `app.b4a.mangatrix.se_controle_ai`** — sobra do template
  que gerou o projeto. Trocar agora é barato; depois de publicar, não.
- **O backend não tem autenticação nem noção de usuário.** Hoje é single-user na
  máquina local. Qualquer plano de publicar o app exige resolver isso primeiro.

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

1. **Autenticação e multi-usuário** — precisa existir? Muda o backend, não só o app.
2. **Offline** — cache local (drift/sqflite) ou o app só funciona conectado?
3. ~~**`intl`**~~ — **resolvido em 19/08: não entra.** Moeda já é `Money`, e data
   passou a ser `IsoDate`, as duas por corte de string e sem `DateTime` no
   caminho. É a mesma razão do `Month`: `DateTime` carrega fuso, e fuso é o que
   faz uma data andar um dia para trás. Reabrir isso só se aparecer localização
   de verdade — mais de um idioma na tela.
4. **Onde o backend vai rodar** — só local em Docker, ou hospedado?
