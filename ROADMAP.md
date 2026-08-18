# Roadmap — se_controle_ai

App Flutter do controle de gastos, cliente da API `expense-tracker-api`
(Node + Express + Postgres, rodando em Docker na mesma máquina).

## Onde estamos

*Atualizado em 18/08/2026.*

Flutter 3.44.9 · Dart 3.12.2 · **Fases 0 e 1 concluídas** · a home lê e
apresenta o resumo do mês, e já foi validada contra dados reais do backend.

`flutter analyze` sem issue · **93 testes, todos passando** · `/summary` e
`/summary/projection` reconferidos contra o backend real em Docker.

As seis libs estão em uso:

| Lib | Versão | Papel no app |
|---|---|---|
| `dio` | ^5.11.0 | Cliente HTTP: baseUrl, timeouts, interceptors |
| `multiple_result` | ^5.3.0 | `Result<Sucesso, Falha>` — erro como retorno, não exceção |
| `get_it` | ^9.2.1 | Service locator: Dio, ApiClient, repositórios, controllers |
| `go_router` | ^17.5.0 | Navegação declarativa por rota nomeada + deep link |
| `signals` | ^7.1.0 | Estado reativo: `signal` no controller, `SignalBuilder` na view |
| `pretty_dio_logger` | ^1.4.0 | Log de requisição/resposta em debug, só quando `AppConfig.logHttp` |

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

### Pendências abertas

Duas inconsistências que não quebram nada hoje, mas ficam caras depois que uma
segunda feature copiar o padrão.

1. **O sufixo `Model` está pela metade.** `MonthlySummaryModel` e
   `SummaryLineItemModel` têm; `DebitGroup`, `CreditCardInvoice` e
   `MonthProjection` não, apesar de morarem em arquivos `*_model.dart`. Decidir
   antes da Fase 2, senão cada feature nova herda a dúvida.
2. **`HomeController` é `registerLazySingleton` em produção e `registerFactory`
   no teste** (`injector.dart` vs `test/fixtures/test_injector.dart`). Os
   comentários nos dois arquivos e em `home_page.dart` afirmam "factory, cada
   página tem a própria instância" — o código de produção faz o contrário. Como
   singleton, dois pushes da mesma rota compartilham estado, e o `dispose` do
   primeiro deixaria o segundo com signal morto. Hoje não explode porque a
   `HomePage` nunca chama `dispose` no controller, então o `dispose:` do get_it
   só rodaria num `unregister`/`reset` — o que também significa que os signals
   nunca são liberados.

Falta também `ApiClient.patch`: só existem `get`, `post` e `delete`, e a Fase 2
precisa de `PATCH /incomes/:id/amount`.

Além disso, `dart format` reescreve quatro arquivos que nunca passaram por
formatação: `core/router/app_router.dart`, `core/utils/month.dart`,
`data/models/monthly_summary_model.dart` (linhas em branco sobrando no fim) e
`test/core/utils/money_test.dart`.

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
| `core/shared/widgets/failure_card_widget.dart` | Card de erro único, com ícone e título por tipo de `Failure` |
| `core/utils/base_controller.dart` | Ciclo de vida do controller: `onInit`, `onReady`, `dispose`, com log |
| `core/utils/money.dart` | Centavos ↔ real: `format`, `formatSigned`, `formatCompact`, `tryParse` |
| `core/utils/month.dart` | Competência `YYYY-MM`: label, aritmética, limites do backend |
| `data/models/monthly_summary_model.dart` | `MonthlySummaryModel` — a resposta de `/summary` inteira |
| `data/models/summary_line_item_model.dart` | `SummaryLineItemModel` — a linha usada em ganho, débito e fatura |
| `data/models/debit_group_model.dart` | `DebitGroup` — total + itens do débito |
| `data/models/credit_card_invoice_model.dart` | `CreditCardInvoice` — fatura do mês, com `limitUsage` |
| `data/models/month_projection_model.dart` | `MonthProjection` — um mês de `/summary/projection` |
| `data/repositories/summary_repository.dart` | Interface + impl de `/summary` e `/summary/projection` |
| `features/home/controller/home_controller.dart` | Estado do resumo com signals — **é o molde a copiar** |
| `features/home/view/home_page.dart` | A tela: navegação de mês, `switch` no `ViewState`, pull-to-refresh |
| `features/home/widgets/` | `BalanceCard`, `SummarySection`, `CreditCardInvoiceCard`, `LineItemTile` |

**Um model por arquivo, sem barrel.** Cada consumidor importa o arquivo da classe
que usa. Não existe `models/monthly_summary.dart` reexportando o resto — quem
precisa de `CreditCardInvoice` importa `credit_card_invoice_model.dart`.

### O que já existe em `test/`

| Arquivo | O que faz |
|---|---|
| `fixtures/summary_fixture.dart` | JSON real capturado do backend: mês normal, vazio e no vermelho |
| `fixtures/fake_summary_repository.dart` | Fake do repositório: resposta trocável, `delay` para corrida, `requestedMonths` |
| `fixtures/test_injector.dart` | Registra as dependências da tela com o fake; idempotente entre testes |

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
| ░░░░░░░░░░ | Fases 2 a 8 — não iniciadas |

**Próximo passo: fechar as [pendências abertas](#pendências-abertas) antes de
abrir a Fase 2.** São três mexidas pequenas, e as três ficam mais caras depois de
existir uma segunda feature copiando o padrão:

1. Decidir o sufixo `Model` e aplicar nos cinco models de uma vez.
2. Alinhar o registro do `HomeController` com o que os comentários prometem.
3. `ApiClient.patch`, com caso no grupo `devolve o Response do Dio` — Ganhos
   precisa de `PATCH /incomes/:id/amount`.

Depois disso, Fase 2 (Ganhos), o primeiro CRUD. O padrão a copiar está na
Fase 1 — model, repositório com `try/catch`, controller com signals, view com
`SignalBuilder` e `switch` no `ViewState`. O que ela tem de novo: formulário com
`issues[].path` do 400 ligado ao campo (o `ValidationFailure.messageFor` já
existe esperando por isso) e reajuste vs. correção como duas ações distintas.

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

**Testes que já cobrem a fase** (34 no total, todos passando):
`test/core/utils/money_test.dart` (17 casos: formatação, parse, round-trip),
`test/core/network/api_client_test.dart` (13 casos: 200/204, remoção de query
nula, 400 com issues, 404, 409, 422, 500, corpo HTML de proxy, timeout,
cancelamento, decode quebrado), `test/core/router/app_router_test.dart` (4 casos:
rota inicial, `goNamed`, 404, botão de voltar).

Os 3 casos do grupo `devolve o Response do Dio` são a única coisa que segura o
contrato do `ApiClient` — os outros 10 do arquivo só olham o que é lançado, não o
que é devolvido. Método novo no client entra com caso novo nesse grupo.

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
incluindo mês vazio e mês no vermelho, `limitUsage` e `MonthProjection`),
`home_controller_test.dart` (16 casos: navegação, limites, corrida entre
respostas), `home_page_test.dart` (14 casos de widget), `widget_test.dart`
(1 caso: o app sobe e cai na home).

### Fase 2 — Ganhos · ░░░░░░░░░░ não iniciada
Primeiro CRUD, e o mais simples — é onde o padrão de formulário nasce.

- Listar, criar, encerrar, excluir
- **Reajuste** e **correção** como ações distintas
- Histórico de vigências visível
- `issues[].path` do 400 ligado aos campos

**Pronto quando:** dá para cadastrar um salário, aplicar um aumento a partir de
um mês, e o resumo dos meses anteriores continua com o valor antigo.

### Fase 3 — Cartões · ░░░░░░░░░░ não iniciada
Vem antes de gastos porque gasto no cartão exige `creditCardId`.

- CRUD completo; `closingDay`/`dueDay` com seletor de dia
- Limite opcional

**Pronto quando:** o cartão criado aparece como opção no formulário de gasto.

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
3. **`intl`** — entra para formatar moeda/data, ou formatador próprio para não
   adicionar dependência?
4. **Onde o backend vai rodar** — só local em Docker, ou hospedado?
