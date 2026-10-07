import 'package:se_controle_ai/data/services/selected_month_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:multiple_result/multiple_result.dart';
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
  /// sucesso, e sem rota embaixo o pop não teria para onde voltar.
  Future<void> pumpForm(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
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

  testWidgets('abre no mês selecionado, sem recorrência', (tester) async {
    await pumpForm(tester);

    expect(
      find.text(MonthUtils.label(SelectedMonthService.initial())),
      findsOneWidget,
    );
    // O switch nasce desligado, então a explicação é a do lançamento único.
    expect(
      find.text('Entra só nesta competência — 13º, freela, bônus.'),
      findsOneWidget,
    );
  });

  // O controller é um por app e a página não o libera, então o formulário
  // sobrevive ao fechamento da tela. Quem o limpa é o `startForm`, no
  // `initState`: sem isso o segundo cadastro abriria com o primeiro ainda
  // preenchido.
  testWidgets('reabrir o formulário o encontra limpo', (tester) async {
    await pumpForm(tester);
    await tester.enterText(fieldWithLabel('Descrição'), 'Salário');
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(fieldWithLabel('Descrição')).controller!.text,
      isEmpty,
    );
  });

  testWidgets('salvar vazio mostra o que falta e não chama o backend', (
    tester,
  ) async {
    await pumpForm(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();

    // O markAllAsTouched do submit é o que faz as mensagens aparecerem; sem
    // ele o botão pareceria não fazer nada.
    expect(find.text('Informe a descrição.'), findsOneWidget);
    expect(find.text('Informe o valor.'), findsOneWidget);
    verifyNoCreate();
    expect(find.byType(IncomeFormPage), findsOneWidget);
  });

  testWidgets('preenchido, manda centavos e fecha a tela', (tester) async {
    await pumpForm(tester);

    await tester.enterText(fieldWithLabel('Descrição'), 'Salário');
    await tester.enterText(fieldWithLabel('Valor'), '5000');
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();

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

    await tester.enterText(fieldWithLabel('Descrição'), 'Freela');
    await tester.enterText(fieldWithLabel('Valor'), '1.234,56');
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();

    verify(
      () => repository.create(
        description: 'Freela',
        amountCents: 123456,
        startMonth: any(named: 'startMonth'),
        recurring: any(named: 'recurring'),
      ),
    ).called(1);
  });

  testWidgets('ligar recorrente troca a explicação e o que é enviado', (
    tester,
  ) async {
    await pumpForm(tester);

    await tester.enterText(fieldWithLabel('Descrição'), 'Salário');
    await tester.enterText(fieldWithLabel('Valor'), '5000');
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(find.text('Segue todo mês até você encerrar.'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();

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

    await tester.enterText(fieldWithLabel('Descrição'), 'Aluguel recebido');
    await tester.enterText(fieldWithLabel('Valor'), '1200');
    await tester.tap(find.byTooltip('Próximo mês'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        MonthUtils.label(MonthUtils.next(SelectedMonthService.initial())),
      ),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();

    verify(
      () => repository.create(
        description: 'Aluguel recebido',
        amountCents: 120000,
        startMonth: MonthUtils.next(SelectedMonthService.initial()),
        recurring: any(named: 'recurring'),
      ),
    ).called(1);
  });

  testWidgets('400 do backend aparece embaixo do campo, e a tela fica aberta', (
    tester,
  ) async {
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

    await tester.enterText(fieldWithLabel('Descrição'), 'Salário');
    await tester.enterText(fieldWithLabel('Valor'), '5000');
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();

    expect(find.text('Mês fora da faixa.'), findsOneWidget);
    expect(find.byType(IncomeFormPage), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('falha de rede vira snackbar, não erro de campo', (tester) async {
    stubIncomeOperations(
      repository,
      createResult: Error(
        Failure.fromException(const NetworkException(message: 'sem rede')),
      ),
    );
    await pumpForm(tester);

    await tester.enterText(fieldWithLabel('Descrição'), 'Salário');
    await tester.enterText(fieldWithLabel('Valor'), '5000');
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(
      find.text('Sem conexão com o servidor. Verifique sua internet.'),
      findsOneWidget,
    );
    expect(find.byType(IncomeFormPage), findsOneWidget);
  });
}
