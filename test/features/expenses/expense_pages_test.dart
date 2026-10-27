import 'dart:async';

import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:multiple_result/multiple_result.dart';
import 'package:se_controle_ai/core/config/globals.dart';
import 'package:se_controle_ai/core/di/injector.dart';
import 'package:se_controle_ai/core/errors/failure.dart';
import 'package:se_controle_ai/data/services/selected_month_service.dart';
import 'package:se_controle_ai/core/shared/widgets/month_field_widget.dart';
import 'package:se_controle_ai/core/utils/iso_date_utils.dart';
import 'package:se_controle_ai/core/utils/month_utils.dart';
import 'package:se_controle_ai/data/models/credit_card_model.dart';
import 'package:se_controle_ai/data/models/expense_model.dart';
import 'package:se_controle_ai/data/models/tag_model.dart';
import 'package:se_controle_ai/data/repositories/tag_repository.dart';
import 'package:se_controle_ai/data/services/navigation_service.dart';
import 'package:se_controle_ai/features/expenses/view/expense_detail_page.dart';
import 'package:se_controle_ai/features/expenses/view/expense_form_page.dart';
import 'package:se_controle_ai/features/expenses/view/expense_list_page.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../fixtures/credit_card_fixture.dart';
import '../../fixtures/expense_fixture.dart';
import '../../fixtures/mocks.dart';
import '../../fixtures/test_injector.dart';

/// O dia 1 do mês de hoje, que é o único dia que o calendário sempre oferece:
/// o futuro está apagado, e qualquer outro número seria futuro numa máquina
/// que rode a suíte no começo do mês.
String primeiroDoMes() {
  final hoje = DateTime.now();
  return '${hoje.year.toString().padLeft(4, '0')}-'
      '${hoje.month.toString().padLeft(2, '0')}-01';
}

void main() {
  late MockExpenseRepository repository;
  late MockNavigationService nav;

  setUp(() {
    setupCreditCardTestInjector();
    repository = setupExpenseTestInjector();
    // O dublê é um só para a suíte inteira: sem limpar, o `pop` de um teste
    // contaria no seguinte.
    nav = getIt<NavigationService>() as MockNavigationService;
    clearInteractions(nav);
  });

  /// O toast some sozinho em 3s; sem esperar, o teste acaba com o timer do
  /// Flushbar pendente.
  Future<void> esperarToastSumir(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  }

  Future<void> pumpList(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: ExpenseListPage()));
    await tester.pumpAndSettle();
  }

  /// O `navigatorKey` é o do app porque o recado sai em toast, e o toast
  /// procura o contexto por ele. Quem fecha a tela é o `NavigationService`
  /// dublê, então ela fica montada e o teste confere o `pop`.
  Future<void> pumpForm(WidgetTester tester, {ExpenseModel? expense}) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: Globals.navigatorKey,
        home: ExpenseFormPage(expense: expense),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Escolhe a primeira tag do seletor.
  ///
  /// Virou passo obrigatório de qualquer teste que salve: com a TAG-06 o
  /// formulário não é válido sem tag, e o submit nem chega ao repositório.
  Future<void> escolherTag(WidgetTester tester) async {
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Moradia').last);
    await tester.pumpAndSettle();
  }

  /// Abre o calendário do dia da compra e escolhe o dia 1.
  ///
  /// O `ensureVisible` não é detalhe: o formulário é uma `ListView` e o campo
  /// nasce abaixo da dobra dos 800x600 do teste — sem rolar, o toque cai fora
  /// da árvore e o erro fala de offset, não do campo.
  Future<void> escolherPrimeiroDia(WidgetTester tester) async {
    await tester.ensureVisible(find.byTooltip('Escolher o dia'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Escolher o dia'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(DatePickerDialog),
        matching: find.text('1'),
      ),
    );
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
  }

  /// Pelo mesmo motivo do [tapSalvar]: o "Ajustar competência" fica embaixo do
  /// campo de data, já fora da área visível do teste.
  Future<void> tapAjustar(WidgetTester tester) async {
    final button = find.text('Ajustar competência');
    await tester.scrollUntilVisible(
      button,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  /// O formulário cresceu com o seletor de tipo, e o botão saiu da área
  /// visível do teste — a ListView não constrói o que está fora da tela.
  Future<void> tapSalvar(WidgetTester tester) async {
    final button = find.widgetWithText(FilledButton, 'Salvar');
    // `.first` porque o seletor de tipo também é rolável, e sem escopo o
    // `scrollUntilVisible` acha dois Scrollables e desiste.
    await tester.scrollUntilVisible(
      button,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  /// Leva a ação até a tela e toca nela. `ensureVisible`, e não
  /// `scrollUntilVisible`: o histórico de valores tem uma lista própria no meio
  /// do card do gasto, e o arrasto pelo centro da tela rolaria ela, não a tela.
  /// A tela alta do [pumpDetail] garante que a ação já foi construída.
  Future<void> tocarAcao(WidgetTester tester, String titulo) async {
    await tester.ensureVisible(find.text(titulo));
    await tester.pumpAndSettle();
    await tester.tap(find.text(titulo));
    await tester.pumpAndSettle();
  }

  /// O detalhe recebe o gasto que a lista entregaria pelo `extra` da rota — o
  /// aluguel, a não ser que o teste passe outro.
  Future<void> pumpDetail(WidgetTester tester, {ExpenseModel? expense}) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: Globals.navigatorKey,
        home: ExpenseDetailPage(
          expense: expense ?? ExpenseModel.fromJson(aluguelJson),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('lista', () {
    testWidgets('mostra os gastos com período e categoria', (tester) async {
      await pumpList(tester);

      expect(find.text('Aluguel'), findsOneWidget);
      expect(find.text('Youtube Music'), findsOneWidget);
      expect(find.text('Presente do João'), findsOneWidget);
      expect(
        find.textContaining('Moradia'),
        findsOneWidget,
        reason: 'a categoria entra no subtítulo quando existe',
      );
    });

    // O valor não vem no payload da listagem: sai do histórico, na competência
    // corrente. Sem isso a lista mostraria travessão em tudo.
    testWidgets('mostra o valor vigente, tirado do histórico', (tester) async {
      await pumpList(tester);

      expect(find.text(r'R$ 1.350,00'), findsWidgets);
    });

    testWidgets('gasto de mês único fora do mês recebe selo', (tester) async {
      await pumpList(tester);

      // O presente é de 2026-08; fora dele o selo vira "Encerrado", dentro dele
      // "Mês único". Um dos dois tem que estar na tela.
      expect(find.textContaining(RegExp('Mês único|Encerrado')), findsWidgets);
    });

    // O bug que este teste fecha: a tela mostrava o total de `MonthUtils.current()`
    // enquanto a home estava em outro mês. Quem olhava setembro via o total de
    // agosto — e, com tudo começando em setembro, via R$ 0,00.
    testWidgets('o total e as linhas seguem o mês selecionado na home', (
      tester,
    ) async {
      final atual = SelectedMonthService.initial();
      final proximo = MonthUtils.next(atual);
      final presenteNoProximo = <String, dynamic>{
        ...presenteJson,
        'startMonth': proximo,
        'endMonth': proximo,
        'history': <Map<String, dynamic>>[
          {'amountCents': 18000, 'validFrom': proximo, 'validTo': proximo},
        ],
      };

      setupExpenseTestInjector(
        mock: expenseRepositoryMock(
          list: Success(
            [
              aluguelJson,
              presenteNoProximo,
            ].map(ExpenseModel.fromJson).toList(),
          ),
        ),
      );
      await pumpList(tester);

      // No mês corrente o presente ainda não saiu: só o aluguel conta.
      expect(
        find.descendant(
          of: find.widgetWithText(Row, 'Sai em ${MonthUtils.label(atual)}'),
          matching: find.text(r'R$ 1.350,00'),
        ),
        findsOneWidget,
      );

      getIt<SelectedMonthService>().select(proximo);
      await tester.pumpAndSettle();

      // A tela não foi remontada: o mês trocou, o controller refez a busca com
      // o novo `activeFrom` e o rodapé se recompôs, agora com o presente somado.
      expect(
        find.descendant(
          of: find.widgetWithText(Row, 'Sai em ${MonthUtils.label(proximo)}'),
          matching: find.text(r'R$ 1.530,00'),
        ),
        findsOneWidget,
      );
    });

    // GFX-12: nome, dia e valor na mesma linha, que é o que a pessoa pediu
    // para reconhecer a compra sem abrir o detalhe.
    testWidgets('a linha mostra o dia da compra', (tester) async {
      setupExpenseTestInjector(
        mock: expenseRepositoryMock(
          list: Success([ExpenseModel.fromJson(aluguelComDiaJson)]),
        ),
      );

      await pumpList(tester);

      expect(find.text('Aluguel'), findsOneWidget);
      expect(find.text('Compra em 17/08/2026'), findsOneWidget);
      expect(find.text(r'R$ 1.350,00'), findsWidgets);
    });

    // Gasto planejado tem dia no futuro, e a linha muda de verbo: dizer
    // "compra em" sobre o que não aconteceu seria afirmação falsa.
    testWidgets('gasto planejado aparece como previsto', (tester) async {
      final futuro = DateTime.now().add(const Duration(days: 30));
      final iso =
          '${futuro.year.toString().padLeft(4, '0')}-'
          '${futuro.month.toString().padLeft(2, '0')}-'
          '${futuro.day.toString().padLeft(2, '0')}';

      setupExpenseTestInjector(
        mock: expenseRepositoryMock(
          list: Success([
            ExpenseModel.fromJson({
              ...aluguelJson,
              'spentAt': '${iso}T12:00:00.000Z',
            }),
          ]),
        ),
      );

      await pumpList(tester);

      expect(find.textContaining('Previsto para'), findsOneWidget);
      expect(find.textContaining('Compra em'), findsNothing);
    });

    // Enquanto a GFX-12 não estiver no ar, o campo não vem — e a lista
    // continua de pé, com uma linha a menos.
    testWidgets('sem dia da compra a linha não quebra', (tester) async {
      await pumpList(tester);

      expect(find.text('Aluguel'), findsOneWidget);
      expect(find.textContaining('Compra em'), findsNothing);
    });

    testWidgets('lista vazia convida a cadastrar', (tester) async {
      setupExpenseTestInjector(
        mock: expenseRepositoryMock(list: const Success([])),
      );

      await pumpList(tester);

      // "em <mês>" e não "cadastrado": com o `?activeFrom` (GFX-11), lista
      // vazia também é o mês em que nada é cobrado.
      //
      // O mês sai do controller e não de `MonthUtils.current()`: o
      // `SelectedMonthService` é singleton do `getIt` e sobrevive entre os
      // testes deste arquivo — o de cima deixa a home no mês seguinte.
      expect(
        find.text(
          'Nenhum gasto em '
          '${MonthUtils.label(getIt<SelectedMonthService>().month.value)}',
        ),
        findsOneWidget,
      );
    });

    testWidgets('falha mostra o card de erro', (tester) async {
      setupExpenseTestInjector(
        mock: expenseRepositoryMock(
          list: const Error(NetworkFailure(message: 'Sem conexão.')),
        ),
      );

      await pumpList(tester);

      expect(find.text('Sem conexão.'), findsOneWidget);
    });

    // O `Skeletonizer` público não aparece na árvore — quem aparece é o
    // `SkeletonizerScope` que ele monta.
    testWidgets('enquanto carrega, mostra o esqueleto e o seletor de mês', (
      tester,
    ) async {
      final pendente = Completer<void>();
      addTearDown(() {
        if (!pendente.isCompleted) pendente.complete();
      });
      setupExpenseTestInjector(
        mock: expenseRepositoryMock(pendenteAte: pendente.future),
      );

      await tester.pumpWidget(const MaterialApp(home: ExpenseListPage()));
      await tester.pump();

      expect(find.byType(SkeletonizerScope), findsWidgets);
      expect(find.text('Aluguel'), findsNothing);
      expect(
        find.text(MonthUtils.label(getIt<SelectedMonthService>().month.value)),
        findsOneWidget,
      );

      pendente.complete();
      await tester.pumpAndSettle();

      expect(find.text('Aluguel'), findsOneWidget);
    });
  });

  group('formulário de cadastro', () {
    testWidgets('abre no débito, e sem seletor de cartão', (tester) async {
      await pumpForm(tester);

      expect(find.text('Novo gasto'), findsOneWidget);
      expect(find.text('Débito'), findsOneWidget);
      expect(find.text('Valor por mês'), findsOneWidget);
      expect(find.text('Cartão'), findsOneWidget);
      // Um só: o da categoria, que é obrigatória e está sempre visível. O do
      // cartão só aparece depois de escolher cartão.
      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    });

    // GFX-12 na tela: o dia é o único campo de tempo do formulário, nasce em
    // hoje, e não há mais seletor de competência para contradizê-lo.
    testWidgets('o dia nasce em hoje, e o mês sumiu da tela', (tester) async {
      await pumpForm(tester);

      expect(find.text('Dia da compra'), findsOneWidget);
      expect(find.text(IsoDateUtils.fullLabel(primeiroDoMes())), findsNothing);
      expect(find.text('Não informado'), findsNothing);

      expect(find.text('A partir de'), findsNothing);
      expect(find.byType(MonthFieldWidget), findsNothing);
    });

    testWidgets('o parcelado também perdeu o seletor de competência', (
      tester,
    ) async {
      await pumpForm(tester);

      await tester.tap(find.text('Parcelado'));
      await tester.pumpAndSettle();

      expect(find.text('Primeira parcela'), findsNothing);
      expect(find.byType(MonthFieldWidget), findsNothing);
      expect(find.text('Dia da compra'), findsOneWidget);
    });

    // O seletor não voltou para a tela: ele voltou para **debaixo** dela, atrás
    // de um botão. Quem concorda com a conta continua vendo um campo de tempo
    // só; quem discorda tem como vencer a regra sem apagar e refazer o gasto.
    testWidgets('"Ajustar competência" revela o seletor de mês', (
      tester,
    ) async {
      await pumpForm(tester);

      expect(find.byType(MonthFieldWidget), findsNothing);

      await tapAjustar(tester);

      expect(find.byType(MonthFieldWidget), findsOneWidget);
      expect(find.text('Competência'), findsOneWidget);
      // O botão sai de cena depois de usado: não há o que ajustar duas vezes.
      expect(find.text('Ajustar competência'), findsNothing);
    });

    testWidgets('no parcelado o ajuste move a primeira parcela', (
      tester,
    ) async {
      await pumpForm(tester);

      await tester.tap(find.text('Parcelado'));
      await tester.pumpAndSettle();

      await tapAjustar(tester);

      expect(find.byType(MonthFieldWidget), findsOneWidget);
    });

    // Em edição a competência nem viaja no PATCH — um seletor ali seria um
    // campo que não muda nada.
    testWidgets('em edição não há ajuste de competência', (tester) async {
      await pumpForm(tester, expense: ExpenseModel.fromJson(aluguelJson));

      expect(find.text('Ajustar competência'), findsNothing);
      expect(find.byType(MonthFieldWidget), findsNothing);
    });

    // Campo obrigatório não tem o que limpar: o X sairia só para deixar o
    // formulário inválido de propósito.
    testWidgets('não há como esvaziar o dia', (tester) async {
      await pumpForm(tester);

      expect(find.byTooltip('Limpar a data'), findsNothing);
    });

    testWidgets('escolher um dia no calendário preenche o campo', (
      tester,
    ) async {
      await pumpForm(tester);

      await escolherPrimeiroDia(tester);

      // Do relógio, e não da competência: desde que o dia passou a decidir a
      // fatura, o calendário deixou de ser preso ao mês escolhido na tela.
      final esperado = IsoDateUtils.fullLabel(primeiroDoMes());

      expect(find.text(esperado), findsOneWidget);
      expect(find.text('Não informado'), findsNothing);
    });

    // O bug de 10/09/2026 visto da tela: cartão que fecha dia 1, compra
    // lançada depois disso, e a primeira parcela caindo na fatura de setembro
    // — que já tinha fechado. A competência tem que pular para a aberta, e a
    // tela tem que dizer por quê.
    testWidgets('a fatura fechada não recebe a compra, e a tela explica', (
      tester,
    ) async {
      setupCreditCardTestInjector(
        mock: creditCardRepositoryMock(
          list: Success([
            CreditCardModel.fromJson({...nubankJson, 'closingDay': 1}),
          ]),
        ),
      );
      await pumpForm(tester);

      await tester.tap(find.text('Cartão'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nubank ••••4321').last);
      await tester.pumpAndSettle();

      await escolherPrimeiroDia(tester);

      // Dia 1 é o próprio fechamento: a fatura deste mês fechou nele. Se hoje
      // ainda for dia 1, ela continua aberta e a compra fica aqui mesmo.
      final hoje = DateTime.now();
      final mes = MonthUtils.of(hoje.year, hoje.month);
      final esperada = hoje.day <= 1 ? mes : MonthUtils.next(mes);

      // O seletor de mês não existe mais: o texto embaixo do calendário é o
      // único lugar da tela que diz onde o gasto vai cair.
      expect(
        find.textContaining(MonthUtils.label(esperada).toLowerCase()),
        findsOneWidget,
        reason: 'o texto de apoio nomeia a fatura que recebeu a compra',
      );
      // No dia 1 a fatura ainda está aberta e não há salto para explicar;
      // em qualquer outro dia a tela tem que dizer por que o mês mudou.
      if (hoje.day > 1) {
        expect(find.textContaining('já fechou dia 1'), findsOneWidget);
      }
    });

    // O critério da Fase 3, na tela: o cartão cadastrado aparece como opção.
    testWidgets('escolher cartão revela o seletor com os cartões', (
      tester,
    ) async {
      await pumpForm(tester);

      await tester.tap(find.text('Cartão'));
      await tester.pumpAndSettle();

      // Dois agora: o da categoria e o do cartão que acabou de aparecer.
      expect(find.byType(DropdownButtonFormField<String>), findsNWidgets(2));

      await tester.tap(find.byType(DropdownButtonFormField<String>).last);
      await tester.pumpAndSettle();

      expect(find.text('Nubank ••••4321'), findsWidgets);
    });

    // Como no formulário de cartão: o Salvar só habilita com o formulário
    // válido, então o vazio nem tem como chegar ao backend.
    testWidgets('formulário vazio deixa o Salvar desabilitado', (tester) async {
      await pumpForm(tester);

      final button = find.widgetWithText(FilledButton, 'Salvar');
      await tester.scrollUntilVisible(
        button,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(tester.widget<FilledButton>(button).onPressed, isNull);
    });

    // A competência sai do dia, então o gasto pode cair fora do mês que a
    // pessoa está olhando. Sem levar a home junto, ele sumiria da tela e a
    // leitura seria "não salvou".
    testWidgets('salvar leva a home para o mês onde o gasto caiu', (
      tester,
    ) async {
      final outroMes = MonthUtils.next(MonthUtils.next(MonthUtils.current()));
      getIt<SelectedMonthService>().select(outroMes);

      await pumpForm(tester);
      await escolherTag(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'Descrição').first,
        'Mercado',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Valor por mês').first,
        '2500',
      );
      await tapSalvar(tester);

      verify(() => nav.pop()).called(1);
      expect(getIt<SelectedMonthService>().month.value, MonthUtils.current());
      expect(find.byType(Flushbar), findsOneWidget);
      expect(find.textContaining('Lançado em'), findsOneWidget);

      await esperarToastSumir(tester);
    });

    testWidgets('falha de rede avisa por toast, e a tela continua', (
      tester,
    ) async {
      setupExpenseTestInjector(
        mock: expenseRepositoryMock(
          create: const Error(NetworkFailure(message: 'Sem conexão.')),
        ),
      );

      await pumpForm(tester);

      await tester.enterText(find.byType(TextField).first, 'Aluguel');
      await escolherTag(tester);
      await tester.enterText(find.byType(TextField).at(2), '1200,00');
      await tapSalvar(tester);

      verifyNever(() => nav.pop());
      expect(find.byType(Flushbar), findsOneWidget);
      expect(find.text('Sem conexão.'), findsOneWidget);

      await esperarToastSumir(tester);
    });
  });

  group('nova categoria no formulário', () {
    // Quem cria é o `TagListController`, pelo mesmo diálogo da tela de tags.
    // Ele fecha o diálogo devolvendo a tag, e o formulário a seleciona. O
    // `NavigationService` é dublê, então o fechamento de verdade é feito aqui,
    // pelo `navigatorKey`, como o `GoRouter` faria.
    testWidgets('cria pelo diálogo de tags e já seleciona a tag', (
      tester,
    ) async {
      when(() => nav.pop<TagModel>(any())).thenAnswer(
        (invocation) => Globals.navigatorKey.currentState!.pop(
          invocation.positionalArguments.first,
        ),
      );
      final tags = getIt<TagRepository>() as MockTagRepository;

      await pumpForm(tester);

      await tester.tap(find.byTooltip('Nova categoria'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Nome'), 'Mercado');
      await tester.tap(find.byKey(ValueKey(Globals.pallete.first)));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Criar'));
      await tester.pumpAndSettle();

      verify(() => tags.create(name: 'Mercado', color: Globals.pallete.first))
          .called(1);
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        find.descendant(
          of: find.byType(DropdownButtonFormField<String>),
          matching: find.text('Mercado'),
        ),
        findsOneWidget,
      );

      await esperarToastSumir(tester);
    });
  });

  // O texto e o rótulo do campo de dia são montados pela tela, a partir da
  // competência que o controller calcula.
  group('dia da compra', () {
    testWidgets('no débito o texto fala de competência', (tester) async {
      await pumpForm(tester);

      expect(find.textContaining('Entra na competência de'), findsOneWidget);
    });

    testWidgets('no cartão o texto nomeia a fatura e o vencimento', (
      tester,
    ) async {
      await pumpForm(tester);

      await tester.tap(find.text('Cartão'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nubank ••••4321').last);
      await tester.pumpAndSettle();

      // A Nubank da fixture vence dia 17: só o nome do mês não bastava para
      // saber de qual das duas faturas a frase está falando.
      expect(find.textContaining('vence 17/'), findsOneWidget);
    });

    // Assinatura não se compra num dia; ela começa num.
    testWidgets('recorrente troca o rótulo do campo', (tester) async {
      await pumpForm(tester);

      expect(find.text('Dia da compra'), findsOneWidget);

      final recorrente = find.text('Recorrente');
      await tester.scrollUntilVisible(
        recorrente,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(recorrente);
      await tester.pumpAndSettle();

      expect(find.text('Começou em'), findsOneWidget);
    });
  });

  group('carregando', () {
    testWidgets('o formulário mostra o esqueleto até cartões e tags chegarem', (
      tester,
    ) async {
      final pendente = Completer<void>();
      addTearDown(() {
        if (!pendente.isCompleted) pendente.complete();
      });
      setupCreditCardTestInjector(
        mock: creditCardRepositoryMock(pendenteAte: pendente.future),
      );

      await tester.pumpWidget(const MaterialApp(home: ExpenseFormPage()));
      await tester.pump();

      expect(find.byType(SkeletonizerScope), findsWidgets);

      pendente.complete();
      await tester.pumpAndSettle();

      expect(find.byType(SkeletonizerScope), findsNothing);
      expect(find.widgetWithText(TextField, 'Descrição'), findsOneWidget);
    });
  });

  group('formulário de edição', () {
    testWidgets('abre preenchido e sem os campos de dinheiro', (tester) async {
      await pumpForm(tester, expense: ExpenseModel.fromJson(aluguelJson));

      expect(find.text('Editar gasto'), findsOneWidget);
      expect(find.text('Aluguel'), findsOneWidget);
      expect(find.text('Moradia'), findsOneWidget);
      // GFX-06: dinheiro não se edita aqui — muda por reajuste ou correção.
      expect(find.text('Valor por mês'), findsNothing);
      expect(find.text('A partir de'), findsNothing);
      expect(find.text('Recorrente'), findsNothing);
    });

    testWidgets('cartões que não chegam mostram erro, e não formulário', (
      tester,
    ) async {
      setupCreditCardTestInjector(
        mock: creditCardRepositoryMock(
          list: const Error(NetworkFailure(message: 'Sem conexão.')),
        ),
      );

      await pumpForm(tester, expense: ExpenseModel.fromJson(aluguelJson));

      expect(find.text('Sem conexão.'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Salvar'), findsNothing);
    });
  });

  group('detalhe', () {
    testWidgets('mostra valor, período e forma de pagamento', (tester) async {
      await pumpDetail(tester);

      expect(find.text('Aluguel'), findsOneWidget);
      // O valor do mês, e de novo no histórico, que fica dentro do card.
      expect(find.text(r'R$ 1.350,00'), findsWidgets);
      expect(find.textContaining('Recorrente desde'), findsOneWidget);
      expect(find.textContaining('No débito'), findsOneWidget);
    });

    testWidgets('o detalhe mostra o dia da compra', (tester) async {
      await pumpDetail(
        tester,
        expense: ExpenseModel.fromJson(aluguelComDiaJson),
      );

      expect(find.text('Compra em 17/08/2026'), findsOneWidget);
      // A competência de início é outra data, e continua na tela: o aluguel é
      // cobrado desde janeiro, e a compra deste registro é de agosto.
      expect(find.textContaining('Recorrente desde'), findsOneWidget);
    });

    testWidgets('gasto no cartão mostra o nome do cartão', (tester) async {
      await pumpDetail(tester, expense: ExpenseModel.fromJson(youtubeJson));

      expect(find.textContaining('Nubank ••••4321'), findsOneWidget);
    });

    // A prova visual de que o reajuste de julho não mexeu em janeiro.
    testWidgets('histórico aparece quando há mais de uma vigência', (
      tester,
    ) async {
      await pumpDetail(tester);

      // Dentro do card do gasto, como no de ganho.
      expect(find.text('Histórico de valores'), findsOneWidget);
      expect(
        find.text(r'R$ 1.200,00'),
        findsOneWidget,
        reason: 'a vigência antiga continua no histórico, com o valor de lá',
      );
    });

    testWidgets('gasto encerrado esconde as operações de dinheiro', (
      tester,
    ) async {
      await pumpDetail(tester, expense: ExpenseModel.fromJson(presenteJson));

      expect(find.text('Reajustar'), findsNothing);
      expect(find.text('Corrigir valor'), findsNothing);
      expect(find.text('Encerrar'), findsNothing);
      // Editar dados e excluir continuam: os dois valem em gasto encerrado.
      expect(find.text('Editar dados'), findsOneWidget);
      expect(find.text('Excluir'), findsOneWidget);
    });

    testWidgets('reajuste manda valor e mês', (tester) async {
      await pumpDetail(tester);

      await tester.tap(find.text('Reajustar'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '1500,00');
      await tester.tap(find.widgetWithText(FilledButton, 'Reajustar'));
      await tester.pumpAndSettle();

      verify(
        () => repository.adjust(
          aluguelJson['id'] as String,
          amountCents: 150000,
          effectiveFrom: any(named: 'effectiveFrom'),
        ),
      ).called(1);
      // O diálogo e o detalhe: quem mostra o valor novo é a lista.
      verify(() => nav.pop()).called(2);
    });

    // O 422 do backend sai por toast, e o diálogo fica aberto para a correção.
    testWidgets('recusa do reajuste avisa por toast, e o diálogo continua', (
      tester,
    ) async {
      setupExpenseTestInjector(
        mock: expenseRepositoryMock(
          operations: const Error(
            DomainRuleFailure(
              message: 'Reajuste precisa valer de 2026-09 em diante.',
            ),
          ),
        ),
      );

      await pumpDetail(tester);

      await tester.tap(find.text('Reajustar'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '1500,00');
      await tester.tap(find.widgetWithText(FilledButton, 'Reajustar'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      verifyNever(() => nav.pop());
      expect(find.byType(Flushbar), findsOneWidget);
      expect(
        find.text('Reajuste precisa valer de 2026-09 em diante.'),
        findsOneWidget,
      );

      await esperarToastSumir(tester);
    });

    testWidgets('correção manda só o valor', (tester) async {
      await pumpDetail(tester);

      await tocarAcao(tester, 'Corrigir valor');

      await tester.enterText(find.byType(TextField).first, '1400,00');
      await tester.tap(find.widgetWithText(FilledButton, 'Corrigir'));
      await tester.pumpAndSettle();

      verify(
        () => repository.correct(
          aluguelJson['id'] as String,
          amountCents: 140000,
        ),
      ).called(1);
    });

    testWidgets('encerramento pede o último mês pago', (tester) async {
      await pumpDetail(tester);

      await tocarAcao(tester, 'Encerrar');

      expect(find.text('Último mês pago'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Encerrar'));
      await tester.pumpAndSettle();

      verify(
        () => repository.close(
          aluguelJson['id'] as String,
          lastMonth: any(named: 'lastMonth'),
        ),
      ).called(1);
    });

    testWidgets('exclusão pede confirmação antes de excluir', (tester) async {
      await pumpDetail(tester);

      await tocarAcao(tester, 'Excluir');

      expect(find.textContaining('como se nunca'), findsOneWidget);
      verifyNever(() => repository.delete(any()));

      await tester.tap(find.widgetWithText(FilledButton, 'Excluir'));
      await tester.pumpAndSettle();

      verify(() => repository.delete(aluguelJson['id'] as String)).called(1);
      // A confirmação e a tela do gasto, que deixou de existir.
      verify(() => nav.pop()).called(2);
    });
  });
}
