import 'dart:async';

import 'package:another_flushbar/flushbar.dart';
import 'package:se_controle_ai/data/services/selected_month_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:multiple_result/multiple_result.dart';
import 'package:se_controle_ai/core/config/globals.dart';
import 'package:se_controle_ai/core/errors/app_exception.dart';
import 'package:se_controle_ai/core/errors/failure.dart';
import 'package:se_controle_ai/core/utils/month_utils.dart';
import 'package:se_controle_ai/features/incomes/view/income_form_page.dart';

import '../../fixtures/mocks.dart';
import '../../fixtures/test_injector.dart';

void main() {
  late MockIncomeRepository repository;

  setUp(() {
    repository = setupIncomeTestInjector();
  });

  /// Empilha o formulário sobre uma tela qualquer: ele fecha com `pop` no
  /// sucesso, e sem rota embaixo o pop não teria para onde voltar. O
  /// `navigatorKey` é o do app porque a falha geral sai em toast, e o toast
  /// procura o contexto por ele.
  Future<void> pumpForm(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: Globals.navigatorKey,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<String>(
                  builder: (_) => const IncomeFormPage(),
                ),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  void verifyNoCreate() => verifyNever(
    () => repository.create(
      description: any(named: 'description'),
      amountCents: any(named: 'amountCents'),
      startMonth: any(named: 'startMonth'),
      recurring: any(named: 'recurring'),
    ),
  );

  Finder fieldWithLabel(String label) =>
      find.ancestor(of: find.text(label), matching: find.byType(TextField));

  bool recurringOn(WidgetTester tester) =>
      tester.widget<Switch>(find.byType(Switch)).value;

  /// O Salvar só liga num frame em que o form já está válido, e o `enterText`
  /// não redesenha a tela — por isso o `pump` vem antes do toque.
  Future<void> save(WidgetTester tester) async {
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();
  }

  testWidgets('abre no mês selecionado, sem recorrência', (tester) async {
    await pumpForm(tester);

    expect(
      find.text(MonthUtils.label(SelectedMonthService.initial())),
      findsOneWidget,
    );
    expect(recurringOn(tester), isFalse);
  });

  // O controller é um por app e a página não o libera, então o formulário
  // sobrevive ao fechamento da tela. Quem o limpa é o `startForm`, no
  // `initState`: sem isso o segundo cadastro abriria com o primeiro ainda
  // preenchido.
  testWidgets('reabrir o formulário o encontra limpo', (tester) async {
    await pumpForm(tester);
    await tester.enterText(fieldWithLabel('Título'), 'Salário');
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(fieldWithLabel('Título')).controller!.text,
      isEmpty,
    );
    // O switch é um signal, fora do form: o `reset` não o alcança.
    expect(recurringOn(tester), isFalse);
  });

  // Quem barra o formulário incompleto é o botão: o `submit` não confere.
  testWidgets('Salvar fica desabilitado até o formulário fechar', (
    tester,
  ) async {
    await pumpForm(tester);

    FilledButton salvar() =>
        tester.widget(find.widgetWithText(FilledButton, 'Salvar'));

    expect(salvar().onPressed, isNull);

    await tester.enterText(fieldWithLabel('Título'), 'Salário');
    await tester.pump();
    expect(salvar().onPressed, isNull);

    await tester.enterText(fieldWithLabel('Valor'), '5000');
    await tester.pump();
    expect(salvar().onPressed, isNotNull);

    verifyNoCreate();
  });

  testWidgets('preenchido, manda centavos e fecha a tela', (tester) async {
    await pumpForm(tester);

    await tester.enterText(fieldWithLabel('Título'), 'Salário');
    await tester.enterText(fieldWithLabel('Valor'), '5000');
    await save(tester);

    // 5000 digitado são cinco mil reais: o accessor entrega 500000 centavos.
    verify(
      () => repository.create(
        description: 'Salário',
        amountCents: 500000,
        startMonth: SelectedMonthService.initial(),
        recurring: false,
      ),
    ).called(1);
    expect(find.byType(IncomeFormPage), findsNothing);
  });

  testWidgets('centavo digitado chega inteiro', (tester) async {
    await pumpForm(tester);

    await tester.enterText(fieldWithLabel('Título'), 'Freela');
    await tester.enterText(fieldWithLabel('Valor'), '1.234,56');
    await save(tester);

    verify(
      () => repository.create(
        description: 'Freela',
        amountCents: 123456,
        startMonth: any(named: 'startMonth'),
        recurring: any(named: 'recurring'),
      ),
    ).called(1);
  });

  testWidgets('ligar recorrente liga o switch e muda o que é enviado', (
    tester,
  ) async {
    await pumpForm(tester);

    await tester.enterText(fieldWithLabel('Título'), 'Salário');
    await tester.enterText(fieldWithLabel('Valor'), '5000');
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(recurringOn(tester), isTrue);

    await save(tester);

    verify(
      () => repository.create(
        description: 'Salário',
        amountCents: 500000,
        startMonth: any(named: 'startMonth'),
        recurring: true,
      ),
    ).called(1);
  });

  testWidgets('seta avança a competência enviada', (tester) async {
    await pumpForm(tester);

    await tester.enterText(fieldWithLabel('Título'), 'Aluguel recebido');
    await tester.enterText(fieldWithLabel('Valor'), '1200');
    await tester.tap(find.byTooltip('Próximo mês'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        MonthUtils.label(MonthUtils.next(SelectedMonthService.initial())),
      ),
      findsOneWidget,
    );

    await save(tester);

    verify(
      () => repository.create(
        description: 'Aluguel recebido',
        amountCents: 120000,
        startMonth: MonthUtils.next(SelectedMonthService.initial()),
        recurring: any(named: 'recurring'),
      ),
    ).called(1);
  });

  // É o `saving` do controller que gira o botão — e ele desabilitado é o que
  // impede o segundo toque de cadastrar duas vezes.
  testWidgets('Salvar gira enquanto o cadastro não volta', (tester) async {
    final segura = Completer<void>();
    stubIncomeOperations(repository, pendenteAte: segura.future);
    await pumpForm(tester);

    await tester.enterText(fieldWithLabel('Título'), 'Salário');
    await tester.enterText(fieldWithLabel('Valor'), '5000');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pump();

    final button = find.byType(FilledButton);
    expect(
      find.descendant(
        of: button,
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    expect(tester.widget<FilledButton>(button).onPressed, isNull);

    segura.complete();
    await tester.pumpAndSettle();

    expect(find.byType(IncomeFormPage), findsNothing);
  });

  /// O toast sai 300ms depois de a tela fechar e some sozinho em 3s. Sem
  /// esperar por ele, o teste acaba com o timer do Flushbar ainda pendente.
  Future<void> waitToast(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  }

  /// Salva o formulário preenchido e dá ao toast de falha o tempo de entrar.
  Future<void> saveFailing(WidgetTester tester) async {
    await tester.enterText(fieldWithLabel('Título'), 'Salário');
    await tester.enterText(fieldWithLabel('Valor'), '5000');
    await save(tester);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
  }

  // A tela fecha com ou sem sucesso, como o diálogo de tag, e a falha chega
  // por toast já sobre a tela de baixo.
  testWidgets('falha de rede fecha a tela e avisa por toast', (tester) async {
    stubIncomeOperations(
      repository,
      createResult: Error(
        Failure.fromException(const NetworkException(message: 'sem rede')),
      ),
    );
    await pumpForm(tester);

    await saveFailing(tester);

    expect(find.byType(IncomeFormPage), findsNothing);
    expect(find.byType(Flushbar), findsOneWidget);
    expect(
      find.text('Sem conexão com o servidor. Verifique sua internet.'),
      findsOneWidget,
    );

    await waitToast(tester);
  });

  testWidgets('400 do backend também vira toast', (tester) async {
    stubIncomeOperations(
      repository,
      createResult: Error(
        Failure.fromException(
          const BadRequestException(
            message: 'Dados inválidos',
            issues: [
              FieldIssue(path: 'startMonth', message: 'Mês fora da faixa.'),
            ],
          ),
        ),
      ),
    );
    await pumpForm(tester);

    await saveFailing(tester);

    expect(find.byType(IncomeFormPage), findsNothing);
    expect(find.byType(Flushbar), findsOneWidget);
    expect(find.text('Dados inválidos'), findsOneWidget);

    await waitToast(tester);
  });
}
