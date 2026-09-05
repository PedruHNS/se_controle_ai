import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:multiple_result/multiple_result.dart';
import 'package:se_controle_ai/core/errors/failure.dart';
import 'package:se_controle_ai/core/month/selected_month_service.dart';
import 'package:se_controle_ai/data/models/expense_model.dart';
import 'package:se_controle_ai/features/expenses/controller/expense_detail_controller.dart';
import 'package:se_controle_ai/features/expenses/controller/expense_form_controller.dart';
import 'package:se_controle_ai/features/expenses/view/expense_detail_page.dart';
import 'package:se_controle_ai/features/expenses/view/expense_form_page.dart';

import '../../fixtures/expense_fixture.dart';
import '../../fixtures/mocks.dart';
import '../../fixtures/tag_fixture.dart';
import '../../fixtures/test_injector.dart';

void main() {
  late MockExpenseRepository repository;
  late MockCreditCardRepository cards;
  late MockTagRepository tags;

  setUp(() {
    cards = setupCreditCardTestInjector();
    // O setupExpense já registra as tags no getIt; aqui é o mesmo mock, para o
    // teste poder construir o controller à mão.
    tags = setupTagTestInjector();
    repository = setupExpenseTestInjector(
      mock: expenseRepositoryMock(
        detail: Success(ExpenseModel.fromJson(geladeiraJson)),
      ),
    );
  });

  group('model', () {
    final geladeira = ExpenseModel.fromJson(geladeiraJson);

    test('lê as dez parcelas', () {
      expect(geladeira.installments, hasLength(10));
      expect(geladeira.installments.first.label, '1/10');
      expect(geladeira.installments.first.referenceMonth, '2026-01');
      expect(geladeira.history, isEmpty);
    });

    // O valor de um mês vem da parcela daquele mês, e não de vigência — é a
    // outra metade do GFX-09, e quem chama não precisa saber de que tipo é.
    test('o valor do mês sai da parcela', () {
      expect(geladeira.amountCentsIn('2026-03'), 30000);
      expect(geladeira.amountCentsIn('2026-11'), isNull);
      expect(geladeira.installmentLabelIn('2026-03'), '3/10');
      expect(geladeira.installmentLabelIn('2026-11'), isNull);
    });

    test('gasto fixo não tem parcela nenhuma', () {
      final aluguel = ExpenseModel.fromJson(aluguelJson);

      expect(aluguel.installments, isEmpty);
      expect(aluguel.installmentLabelIn('2026-03'), isNull);
    });

    // GPR-08, GPR-10 e GPR-11 numa resposta só: as quatro primeiras ficaram com
    // o valor antigo, a numeração continuou em 5, e o "de N" das antigas virou
    // 12 — porque é a mesma compra, agora em doze vezes.
    test('reparcelada, as antigas ficam e a numeração continua', () {
      final depois = ExpenseModel.fromJson(geladeiraReparceladaJson);

      expect(depois.installments, hasLength(12));
      expect(depois.amountCentsIn('2026-04'), 30000);
      expect(depois.amountCentsIn('2026-05'), 35000);
      expect(depois.installmentLabelIn('2026-01'), '1/12');
      expect(depois.installmentLabelIn('2026-05'), '5/12');
      expect(depois.totalCents, 400000);
    });
  });

  group('cadastro', () {
    late ExpenseFormController controller;
    late SelectedMonthService month;

    setUp(() {
      month = SelectedMonthService();
      controller = ExpenseFormController(repository, cards, tags, month);
    });
    tearDown(() {
      controller.dispose();
      month.dispose();
    });

    test('nasce como fixo', () async {
      await controller.start();

      expect(controller.selectedType, ExpenseType.fixed);
    });

    test('parcelado manda total, quantidade e primeira competência', () async {
      await controller.start();
      controller.selectType(ExpenseType.installment);

      controller.form.patchValue({
        ExpenseFormController.tagId: moradiaTagId,
        ExpenseFormController.description: 'Geladeira',
        ExpenseFormController.totalCents: 300000,
        ExpenseFormController.installmentsCount: 10,
        ExpenseFormController.firstMonth: '2026-01',
      });

      final id = await controller.submit();

      expect(id, 'novo-gasto');
      verify(
        () => repository.createInstallment(
          description: 'Geladeira',
          paymentMethod: PaymentMethod.debit,
          totalCents: 300000,
          installmentsCount: 10,
          firstMonth: '2026-01',
          tagId: any(named: 'tagId'),
          notes: null,
          creditCardId: null,
        ),
      ).called(1);
    });

    // Os campos do outro tipo nascem vazios e inválidos. Se a validação olhasse
    // o grupo inteiro, escolher parcelado travaria o salvamento por causa de um
    // "valor por mês" que nem está na tela.
    test('os campos do tipo não escolhido não travam o salvamento', () async {
      await controller.start();
      controller.selectType(ExpenseType.installment);

      controller.form.patchValue({
        ExpenseFormController.tagId: moradiaTagId,
        ExpenseFormController.description: 'Geladeira',
        ExpenseFormController.totalCents: 300000,
      });

      expect(
        controller.control<int>(ExpenseFormController.amountCents).invalid,
        isTrue,
        reason: 'o campo do gasto fixo continua vazio, e tudo bem',
      );
      expect(await controller.submit(), isNotNull);
    });

    test('voltar para fixo manda o cadastro de fixo', () async {
      await controller.start();
      controller.selectType(ExpenseType.installment);
      controller.selectType(ExpenseType.fixed);

      controller.form.patchValue({
        ExpenseFormController.tagId: moradiaTagId,
        ExpenseFormController.description: 'Aluguel',
        ExpenseFormController.amountCents: 120000,
      });

      await controller.submit();

      verify(
        () => repository.createFixed(
          description: any(named: 'description'),
          paymentMethod: any(named: 'paymentMethod'),
          amountCents: 120000,
          startMonth: any(named: 'startMonth'),
          tagId: any(named: 'tagId'),
          notes: any(named: 'notes'),
          creditCardId: any(named: 'creditCardId'),
          recurring: any(named: 'recurring'),
        ),
      ).called(1);
      verifyNever(
        () => repository.createInstallment(
          description: any(named: 'description'),
          paymentMethod: any(named: 'paymentMethod'),
          totalCents: any(named: 'totalCents'),
          installmentsCount: any(named: 'installmentsCount'),
          firstMonth: any(named: 'firstMonth'),
          tagId: any(named: 'tagId'),
          notes: any(named: 'notes'),
          creditCardId: any(named: 'creditCardId'),
        ),
      );
    });

    test('menos de duas parcelas é recusado antes de sair', () async {
      await controller.start();
      controller.selectType(ExpenseType.installment);

      controller.form.patchValue({
        ExpenseFormController.tagId: moradiaTagId,
        ExpenseFormController.description: 'Geladeira',
        ExpenseFormController.totalCents: 300000,
        ExpenseFormController.installmentsCount: 1,
      });

      expect(await controller.submit(), isNull);
      verifyNever(
        () => repository.createInstallment(
          description: any(named: 'description'),
          paymentMethod: any(named: 'paymentMethod'),
          totalCents: any(named: 'totalCents'),
          installmentsCount: any(named: 'installmentsCount'),
          firstMonth: any(named: 'firstMonth'),
          tagId: any(named: 'tagId'),
          notes: any(named: 'notes'),
          creditCardId: any(named: 'creditCardId'),
        ),
      );
    });
  });

  group('operações', () {
    late ExpenseDetailController controller;

    setUp(() => controller = ExpenseDetailController(repository, cards));
    tearDown(() => controller.dispose());

    test('reparcelamento manda os dois totais e o mês', () async {
      await controller.start('gasto-1');

      final failure = await controller.reschedule(
        newTotalCents: 400000,
        newInstallmentsCount: 12,
        fromMonth: '2026-05',
      );

      expect(failure, isNull);
      verify(
        () => repository.reschedule(
          'gasto-1',
          newTotalCents: 400000,
          newInstallmentsCount: 12,
          fromMonth: '2026-05',
        ),
      ).called(1);
      // Recarga silenciosa depois da ação: a de abertura mais esta.
      verify(() => repository.getById('gasto-1', month: null)).called(2);
    });

    test('quitação manda só o mês', () async {
      await controller.start('gasto-1');

      final failure = await controller.settle(fromMonth: '2026-09');

      expect(failure, isNull);
      verify(
        () => repository.settle('gasto-1', fromMonth: '2026-09'),
      ).called(1);
    });

    test('recusa do backend volta como Failure', () async {
      repository = setupExpenseTestInjector(
        mock: expenseRepositoryMock(
          detail: Success(ExpenseModel.fromJson(geladeiraJson)),
          operations: const Error(
            DomainRuleFailure(message: 'Não há parcelas futuras para quitar'),
          ),
        ),
      );
      controller = ExpenseDetailController(repository, cards);
      await controller.start('gasto-1');

      final failure = await controller.settle(fromMonth: '2027-05');

      expect(failure, isA<DomainRuleFailure>());
    });
  });

  group('telas', () {
    Future<void> pumpDetail(WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: ExpenseDetailPage(id: 'gasto-1')),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('o detalhe mostra as ações de parcelado, e não as de fixo', (
      tester,
    ) async {
      await pumpDetail(tester);

      expect(find.text('Reparcelar'), findsOneWidget);
      expect(find.text('Quitar'), findsOneWidget);
      // GPR-17: o backend recusaria as três com 422.
      expect(find.text('Reajustar'), findsNothing);
      expect(find.text('Corrigir valor'), findsNothing);
      expect(find.text('Encerrar'), findsNothing);
    });

    testWidgets('o detalhe lista as parcelas', (tester) async {
      await pumpDetail(tester);

      await tester.scrollUntilVisible(find.text('Parcelas'), 200);
      await tester.pumpAndSettle();

      expect(find.text('1/10'), findsOneWidget);
      expect(find.text('10/10'), findsOneWidget);
    });

    testWidgets('o formulário troca os campos com o tipo', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ExpenseFormPage()));
      await tester.pumpAndSettle();

      expect(find.text('Valor por mês'), findsOneWidget);
      expect(find.text('Total da compra'), findsNothing);

      await tester.tap(find.text('Parcelado'));
      await tester.pumpAndSettle();

      expect(find.text('Total da compra'), findsOneWidget);
      expect(find.text('Em quantas vezes'), findsOneWidget);
      expect(find.text('Valor por mês'), findsNothing);
      expect(find.text('Recorrente'), findsNothing);
    });

    // A conta que a pessoa faria de cabeça, feita na tela — e o aviso do
    // centavo a mais nas primeiras, que é o rateio do GPR-03.
    testWidgets('o formulário mostra quanto fica cada parcela', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ExpenseFormPage()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Parcelado'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.ancestor(
          of: find.text('Total da compra'),
          matching: find.byType(TextField),
        ),
        '100,00',
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('2x de'), findsOneWidget);
    });

    testWidgets('a edição não oferece troca de tipo', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: ExpenseFormPage(id: 'gasto-1')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Parcelado'), findsNothing);
      expect(find.text('À vista'), findsNothing);
    });
  });
}
