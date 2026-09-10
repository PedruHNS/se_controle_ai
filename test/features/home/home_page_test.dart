import 'package:se_controle_ai/core/month/selected_month_service.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:se_controle_ai/core/theme/app_theme.dart';
import 'package:multiple_result/multiple_result.dart';
import 'package:se_controle_ai/core/errors/failure.dart';
import 'package:se_controle_ai/core/utils/month.dart';
import 'package:se_controle_ai/data/models/credit_card_invoice_model.dart';
import 'package:se_controle_ai/core/router/app_router.dart';
import 'package:se_controle_ai/features/home/view/home_page.dart';
import 'package:se_controle_ai/features/home/widgets/credit_card_invoice_card.dart';

import 'package:mocktail/mocktail.dart';

import '../../fixtures/mocks.dart';
import '../../fixtures/summary_fixture.dart';
import '../../fixtures/test_injector.dart';

void main() {
  late MockSummaryRepository repository;

  setUp(() => repository = setupTestInjector());
  // tearDown(resetInjector);

  /// Monta a home numa tela alta o bastante para o resumo inteiro caber.
  ///
  /// O que está fora do viewport de um sliver não está na árvore, e desde que a
  /// home ganhou a segunda seção de gasto ela passa dos 600px do surface padrão
  /// do `flutter_test` — sem isto, `find.text('Nubank ••••4321')` acharia zero e
  /// a asserção estaria medindo altura de card, não conteúdo.
  ///
  /// [inteira] existe para os dois testes que medem a AppBar em tela estreita:
  /// eles escolhem o próprio tamanho, e a tela alta o desfaria.
  Future<void> pumpHome(
    WidgetTester tester, {
    ThemeData? theme,
    bool inteira = true,
  }) async {
    if (inteira) {
      tester.view.physicalSize = const Size(400, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
    }

    await tester.pumpWidget(MaterialApp(theme: theme, home: const HomePage()));
    await tester.pumpAndSettle();
  }

  // O tema escuro não é só uma paleta: `Colors.orange` fixo, card com elevação
  // e cor escrita à mão só aparecem como problema quando a tela monta de
  // verdade nos dois modos.
  group('tema', () {
    for (final (nome, tema) in [
      ('claro', AppTheme.light),
      ('escuro', AppTheme.dark),
    ]) {
      testWidgets('a home monta no tema $nome', (tester) async {
        await pumpHome(tester, theme: tema);

        expect(tester.takeException(), isNull);
        expect(find.text('Comprometido'), findsOneWidget);
      });
    }

    testWidgets('o alerta de comprometimento acompanha o tema', (tester) async {
      await pumpHome(tester, theme: AppTheme.dark);

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold, isNotNull);
      expect(
        AppTheme.dark.appColors.warning,
        isNot(AppTheme.light.appColors.warning),
      );
    });
  });

  group('carregamento', () {
    testWidgets('mostra spinner antes da resposta', (tester) async {
      final segura = Completer<void>();
      stubHome(repository, pendenteAte: segura.future);

      tester.view.physicalSize = const Size(400, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(home: HomePage()));
      await tester.pump();

      // Cinco: uma por seção. Cada uma guarda o próprio lugar enquanto não
      // chega, para o conteúdo não pular quando as respostas entram.
      expect(find.byType(CircularProgressIndicator), findsNWidgets(5));

      // Sem soltar a resposta, o `pumpAndSettle` esperaria para sempre: o
      // indicador de progresso é uma animação que nunca acaba.
      segura.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('conteúdo', () {
    testWidgets('mostra os totais formatados em real', (tester) async {
      await pumpHome(tester);

      // 5.000,00 aparece 3x: no cartão de saldo, no total da seção Ganhos e na
      // linha do Salário — que é o único ganho do mês.
      expect(find.text('R\$ 5.000,00'), findsNWidgets(3));
      // 2x: o "Sai" do cartão de saldo e o total de "Dinheiro e crédito". São o
      // mesmo número por construção — a seção é tudo que sai no mês.
      expect(find.text('R\$ 2.455,90'), findsNWidgets(2)); // gasto
      expect(find.text('R\$ 2.544,10'), findsOneWidget); // saldo
      expect(find.text('Sobram'), findsOneWidget);
      // Rótulos do cartão são curtos, para não repetir o nome das seções.
      expect(find.text('Entra'), findsOneWidget);
      expect(find.text('Sai'), findsOneWidget);
    });

    testWidgets('mostra o comprometido do mês', (tester) async {
      await pumpHome(tester);

      expect(find.text('Comprometido'), findsOneWidget);
      expect(find.text('49.1%'), findsOneWidget);
    });

    testWidgets('lista ganhos e as duas seções de gasto', (tester) async {
      await pumpHome(tester);

      expect(find.text('Ganhos'), findsOneWidget);
      expect(find.text('Salário'), findsOneWidget);
      expect(find.text('Dinheiro e crédito'), findsOneWidget);
      expect(find.text('Dinheiro'), findsOneWidget);
      // Uma vez em cada seção de gasto: o aluguel é débito, e débito também é
      // gasto. É a repetição que as duas seções assumem.
      expect(find.text('Aluguel'), findsNWidgets(2));
    });

    // A razão de a seção de cima existir: sem ela, um gasto no cartão só
    // aparece dentro da fatura, lá embaixo. As duas seções não são a mesma
    // coisa com nomes diferentes — os totais provam.
    testWidgets('a seção de tudo mostra o cartão; a de dinheiro, não', (
      tester,
    ) async {
      await pumpHome(tester);

      final naSecaoDeTudo = find.descendant(
        of: find.ancestor(
          of: find.text('Dinheiro e crédito'),
          matching: find.byType(Card),
        ),
        matching: find.text('Netflix'),
      );
      final naSecaoDeDinheiro = find.descendant(
        of: find.ancestor(
          of: find.text('Dinheiro'),
          matching: find.byType(Card),
        ),
        matching: find.text('Netflix'),
      );

      expect(naSecaoDeTudo, findsOneWidget);
      expect(naSecaoDeDinheiro, findsNothing);

      // R$ 2.455,90 é tudo que sai; R$ 1.800,00 é só o aluguel, que é o que
      // sai do dinheiro. A diferença é a fatura.
      expect(find.text('R\$ 1.800,00'), findsNWidgets(3));
    });

    // A fatura do resumo é a segunda porta do cartão — a outra é a lista de
    // cartões, pelo menu.
    testWidgets('a fatura do cartão é tocável', (tester) async {
      await pumpHome(tester);

      final card = find.byType(CreditCardInvoiceCard);
      expect(card, findsOneWidget);
      expect(
        tester.widget<CreditCardInvoiceCard>(card).onTap,
        isNotNull,
        reason: 'sem onTap o card vira enfeite, e o cartão fica sem porta aqui',
      );
    });

    testWidgets('mostra a fatura do cartão com vencimento e limite', (
      tester,
    ) async {
      await pumpHome(tester);

      expect(find.text('Nubank ••••4321'), findsOneWidget);
      expect(find.text('Vence em 17/08'), findsOneWidget);
      expect(find.text('R\$ 655,90'), findsOneWidget);
      expect(find.textContaining('do limite de R\$ 8.000,00'), findsOneWidget);
    });

    // Com um cartão só, empilhar ou deslizar dá na mesma tela — é com dois que
    // a diferença aparece. Aqui a home é montada de ponta a ponta, e não o
    // carrossel isolado: o que se testa é que a seção continua ligada nele.
    testWidgets('duas faturas saem lado a lado, e não uma sob a outra', (
      tester,
    ) async {
      final faturas = (summaryJson['creditCards'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(CreditCardInvoiceModel.fromJson)
          .toList();
      final segunda = CreditCardInvoiceModel(
        cardId: 'id-inter',
        name: 'Inter',
        label: 'Inter ••••9999',
        dueDate: '2026-08-12',
        limitCents: 200000,
        totalCents: 12000,
        items: const [],
      );
      stubCreditCardSections(
        repository,
        result: Success([...faturas, segunda]),
      );

      await pumpHome(tester);

      final primeiro = tester.getRect(
        find.ancestor(
          of: find.text('Nubank ••••4321'),
          matching: find.byType(CreditCardInvoiceCard),
        ),
      );
      final segundo = tester.getRect(
        find.ancestor(
          of: find.text('Inter ••••9999'),
          matching: find.byType(CreditCardInvoiceCard),
        ),
      );

      expect(segundo.left, greaterThan(primeiro.right));
      expect(segundo.top, primeiro.top);
    });

    testWidgets('item parcelado mostra a parcela; fixo não', (tester) async {
      await pumpHome(tester);

      // Escopado na fatura: os mesmos itens aparecem na seção de gasto do mês,
      // e sem o escopo a contagem falaria de repetição, não de parcela.
      Finder naFatura(Finder alvo) => find.descendant(
        of: find.byType(CreditCardInvoiceCard),
        matching: alvo,
      );

      expect(naFatura(find.text('Notebook')), findsOneWidget);
      expect(naFatura(find.text('Parcela 3/10')), findsOneWidget);
      // Netflix é gasto fixo — installmentLabel nulo, nada de "Parcela".
      expect(naFatura(find.text('Netflix')), findsOneWidget);
      expect(naFatura(find.textContaining('Parcela')), findsOneWidget);
    });
  });

  group('mês no vermelho', () {
    testWidgets('troca o rótulo do saldo e avisa do estouro', (tester) async {
      stubHome(repository, json: negativeSummaryJson);

      await pumpHome(tester);

      expect(find.text('Faltam'), findsOneWidget);
      expect(find.text('-R\$ 1.500,00'), findsOneWidget);
      expect(
        find.text('Os gastos passaram do que entra neste mês.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Acima do limite de R\$ 4.000,00'),
        findsOneWidget,
      );
    });
  });

  group('mês vazio', () {
    testWidgets('mantém o acesso aos ganhos mesmo sem lançamentos', (
      tester,
    ) async {
      stubHome(repository, json: emptySummaryJson);

      await pumpHome(tester);

      expect(find.text('Ganhos'), findsOneWidget);
      expect(
        find.text('Nenhum ganho cadastrado. Toque para adicionar um.'),
        findsOneWidget,
      );
      expect(find.text('Comprometido'), findsNothing);
    });
  });

  group('erro', () {
    testWidgets('falha de rede mostra mensagem e botão de tentar de novo', (
      tester,
    ) async {
      stubHome(repository, failure: const NetworkFailure());

      await pumpHome(tester);

      // Uma vez, não quatro: as quatro seções caíram juntas, então a notícia é
      // da tela, não de uma seção.
      expect(find.text('Sem conexão'), findsOneWidget);
      expect(find.text('Tentar de novo'), findsOneWidget);
    });

    testWidgets('uma seção que falha não derruba as outras', (tester) async {
      stubCreditCardSections(repository, result: const Error(NetworkFailure()));

      await pumpHome(tester);

      // O erro fica no lugar das faturas; ganhos e saldo seguem na tela.
      expect(find.text('Sem conexão'), findsOneWidget);
      expect(find.text('Salário'), findsOneWidget);
      expect(find.text('Ganhos'), findsOneWidget);
    });

    testWidgets('tentar de novo refaz a busca e mostra o conteúdo', (
      tester,
    ) async {
      stubHome(repository, failure: const NetworkFailure());
      await pumpHome(tester);

      stubHome(repository);
      await tester.tap(find.text('Tentar de novo'));
      await tester.pumpAndSettle();

      expect(find.text('Salário'), findsOneWidget);
      expect(find.text('Tentar de novo'), findsNothing);
      verify(() => repository.getBalance(month: any(named: 'month'))).called(2);
    });

    testWidgets('erro que não vale repetir não oferece o botão', (
      tester,
    ) async {
      // 422 é regra de negócio: repetir daria o mesmo resultado.
      stubHome(
        repository,
        failure: const DomainRuleFailure(
          message: 'Gasto no cartão exige informar o cartão',
        ),
      );

      await pumpHome(tester);

      expect(find.text('Operação não permitida'), findsOneWidget);
      expect(find.text('Tentar de novo'), findsNothing);
    });
  });

  group('navegação entre meses', () {
    testWidgets('título mostra a competência em português', (tester) async {
      await pumpHome(tester);

      expect(
        find.text(Month.shortLabel(SelectedMonthService.initial())),
        findsOneWidget,
      );
    });

    testWidgets('seta avança o mês e refaz a busca', (tester) async {
      await pumpHome(tester);
      final start = SelectedMonthService.initial();

      // Escopo na AppBar: a seção de ganhos também tem um chevron, o dela
      // levando para a tela de ganhos.
      await tester.tap(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.chevron_right),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(Month.shortLabel(Month.next(start))), findsOneWidget);
      expect(capturedMonths(repository), [start, Month.next(start)]);
    });

    testWidgets('atalho de voltar ao mês atual aparece só fora dele', (
      tester,
    ) async {
      await pumpHome(tester);

      // O app abre no mês seguinte, então o atalho já nasce visível: a tela
      // não está no mês do relógio.
      expect(find.text('Voltar para o mês atual'), findsOneWidget);

      await tester.tap(find.text('Voltar para o mês atual'));
      await tester.pumpAndSettle();
      expect(find.text('Voltar para o mês atual'), findsNothing);
      expect(find.text(Month.shortLabel(Month.current())), findsOneWidget);

      // E volta a aparecer assim que a pessoa sai do mês corrente de novo.
      await tester.tap(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.chevron_left),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Voltar para o mês atual'), findsOneWidget);
    });

    // Regressão: o atalho morava no `bottom` do AppBar com
    // `preferredSize: Size.fromHeight(0)`. A barra não crescia, o botão ocupava
    // espaço mesmo assim e o rótulo do mês era empurrado para cima do topo
    // (`top: -14`), recortado. Na tela parecia que avançar o mês tinha trocado o
    // nome do mês por um botão. Só a posição pega isso: o rótulo continuava no
    // widget tree, e todo `expect(find.text(...))` seguia verde.
    testWidgets('o rótulo do mês continua dentro da barra fora do mês atual', (
      tester,
    ) async {
      await pumpHome(tester);

      await tester.tap(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.chevron_right),
        ),
      );
      await tester.pumpAndSettle();

      final label = find.text(
        Month.shortLabel(Month.next(SelectedMonthService.initial())),
      );
      expect(label, findsOneWidget);

      final appBar = tester.getRect(find.byType(AppBar));
      final title = tester.getRect(label);

      expect(
        title.top,
        greaterThanOrEqualTo(appBar.top),
        reason: 'o rótulo do mês saiu por cima da barra',
      );
      expect(title.bottom, lessThanOrEqualTo(appBar.bottom));

      // E o atalho não invade a barra: ele vive no corpo, abaixo dela.
      expect(
        tester.getRect(find.text('Voltar para o mês atual')).top,
        greaterThanOrEqualTo(appBar.bottom),
      );
    });

    // Regressão da largura, irmã da de cima: o rótulo cabia na barra até o botão
    // do menu e o sino dividirem espaço com as duas setas. Por extenso ele era
    // cortado em "Agost…", sem o ano — e como o texto seguia inteiro no widget
    // tree, nenhum `find.text` reclamava. Hoje é abreviado e encolhe em vez de
    // cortar; o teste mede a 360dp, largura de aparelho comum.
    testWidgets('o rótulo do mês não é cortado em tela estreita', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpHome(tester, inteira: false);

      final label = find.text(Month.shortLabel(SelectedMonthService.initial()));
      final paragraph = tester.renderObject<RenderParagraph>(label);

      expect(
        paragraph.size.width,
        greaterThanOrEqualTo(paragraph.getMaxIntrinsicWidth(double.infinity)),
        reason: 'o rótulo do mês foi cortado por falta de espaço na barra',
      );

      final bar = tester.getRect(find.byType(AppBar));
      final painted = tester.getRect(label);
      expect(painted.left, greaterThanOrEqualTo(bar.left));
      expect(painted.right, lessThanOrEqualTo(bar.right));
    });
  });

  // `push` não destrói a home: ela fica montada embaixo, com o controller
  // intacto, e nada nela roda quando a tela de cima sai. Quem avisa é o
  // `routeObserver` — sem ele, cadastrar um gasto pela tela de gastos deixava
  // o resumo velho até alguém puxar para atualizar.
  group('voltar de outra tela', () {
    Future<void> pumpComPilha(WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: const HomePage(),
          navigatorObservers: [routeObserver],
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> empilharEVoltar(WidgetTester tester) async {
      Navigator.of(tester.element(find.byType(HomePage))).push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('outra tela')),
        ),
      );
      await tester.pumpAndSettle();

      Navigator.of(tester.element(find.text('outra tela'))).pop();
      await tester.pumpAndSettle();
    }

    testWidgets('recarrega o resumo', (tester) async {
      await pumpComPilha(tester);
      clearInteractions(repository);

      await empilharEVoltar(tester);

      verify(() => repository.getBalance(month: any(named: 'month'))).called(1);
      verify(
        () => repository.getExpenses(month: any(named: 'month')),
      ).called(1);
    });

    // `refresh` é `load(silent: true)`: o conteúdo antigo fica na tela
    // enquanto o novo vem. Piscar a home inteira a cada volta do menu seria
    // pior do que o dado velho por meio segundo.
    testWidgets('sem piscar o conteúdo que já estava na tela', (tester) async {
      await pumpComPilha(tester);

      await empilharEVoltar(tester);

      expect(find.text('Comprometido'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
