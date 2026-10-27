import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:multiple_result/multiple_result.dart';
import 'package:se_controle_ai/core/errors/failure.dart';
import 'package:se_controle_ai/data/services/selected_month_service.dart';
import 'package:se_controle_ai/data/models/expense_model.dart';
import 'package:se_controle_ai/features/expenses/controller/expense_controller.dart';
import 'package:se_controle_ai/features/expenses/view/expense_detail_page.dart';
import 'package:se_controle_ai/features/expenses/view/expense_form_page.dart';

import '../../fixtures/expense_fixture.dart';
import '../../fixtures/mocks.dart';
import '../../fixtures/tag_fixture.dart';
import '../../fixtures/test_injector.dart';

import 'package:se_controle_ai/data/enums/payment_method.dart';
import 'package:se_controle_ai/data/enums/expense_type.dart';

void main() {
  // A recusa avisa por toast, e o toast procura o contexto pelo `navigatorKey`
  // — o que exige o binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockExpenseRepository repository;
  late MockCreditCardRepository cards;
  late MockTagRepository tags;
  late MockNavigationService nav;

  setUp(() {
    cards = setupCreditCardTestInjector();
    // O setupExpense já registra as tags no getIt; aqui é o mesmo mock, para o
    // teste poder construir o controller à mão.
    tags = setupTagTestInjector();
    repository = setupExpenseTestInjector();
    nav = navigationServiceMock();
  });

  // O valor de um mês e o rótulo da parcela são contas, e estão no teste do
  // `ExpenseUtils`. Aqui fica o que o model lê.
  group('model', () {
    final geladeira = ExpenseModel.fromJson(geladeiraJson);

    test('lê as dez parcelas', () {
      expect(geladeira.installments, hasLength(10));
      expect(geladeira.installments.first.number, 1);
      expect(geladeira.installments.first.total, 10);
      expect(geladeira.installments.first.referenceMonth, '2026-01');
      expect(geladeira.history, isEmpty);
    });

    test('gasto fixo não tem parcela nenhuma', () {
      final aluguel = ExpenseModel.fromJson(aluguelJson);

      expect(aluguel.installments, isEmpty);
    });

    // GPR-08, GPR-10 e GPR-11 numa resposta só: as quatro primeiras ficaram com
    // o valor antigo, a numeração continuou em 5, e o "de N" das antigas virou
    // 12 — porque é a mesma compra, agora em doze vezes.
    test('reparcelada, lê as doze parcelas e o novo total', () {
      final depois = ExpenseModel.fromJson(geladeiraReparceladaJson);

      expect(depois.installments, hasLength(12));
      expect(
        depois.installments.every((parcela) => parcela.total == 12),
        isTrue,
      );
      expect(depois.totalCents, 400000);
    });
  });

  group('cadastro', () {
    late ExpenseController controller;
    late SelectedMonthService month;

    setUp(() {
      month = SelectedMonthService();
      controller = ExpenseController(
        repository: repository,
        cardRepository: cards,
        tagRepository: tags,
        selectedMonth: month,
        nav: nav,
      );
    });
    tearDown(() {
      controller.dispose();
      month.dispose();
    });

    test('nasce como fixo', () async {
      await controller.resetForm();

      expect(controller.getType.value, ExpenseType.fixed);
    });

    test('parcelado manda total, quantidade e primeira competência', () async {
      await controller.resetForm();
      controller.setType = ExpenseType.installment;

      controller.form.patchValue({
        'tagId': moradiaTagId,
        'description': 'Geladeira',
        'totalCents': 300000,
        'installmentsCount': 10,
        'firstMonth': '2026-01',
      });

      await controller.onSubmit(expense: null);

      verify(() => nav.pop()).called(1);
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
          spentAt: any(named: 'spentAt'),
        ),
      ).called(1);
    });

    // Os campos do outro tipo nascem vazios e inválidos. Se a validação olhasse
    // o grupo inteiro, escolher parcelado travaria o salvamento por causa de um
    // "valor por mês" que nem está na tela.
    test('os campos do tipo não escolhido não travam o salvamento', () async {
      await controller.resetForm();
      controller.setType = ExpenseType.installment;

      controller.form.patchValue({
        'tagId': moradiaTagId,
        'description': 'Geladeira',
        'totalCents': 300000,
      });

      expect(
        controller.form.control('amountCents').disabled,
        isTrue,
        reason: 'o campo do gasto fixo continua vazio, e tudo bem',
      );
      expect(controller.form.valid, isTrue);
      await controller.onSubmit(expense: null);

      verify(() => nav.pop()).called(1);
    });

    test('voltar para fixo manda o cadastro de fixo', () async {
      await controller.resetForm();
      controller.setType = ExpenseType.installment;
      controller.setType = ExpenseType.fixed;

      controller.form.patchValue({
        'tagId': moradiaTagId,
        'description': 'Aluguel',
        'amountCents': 120000,
      });

      await controller.onSubmit(expense: null);

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
          spentAt: any(named: 'spentAt'),
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
          spentAt: any(named: 'spentAt'),
        ),
      );
    });

    test('menos de duas parcelas deixa o formulário inválido', () async {
      await controller.resetForm();
      controller.setType = ExpenseType.installment;

      controller.form.patchValue({
        'tagId': moradiaTagId,
        'description': 'Geladeira',
        'totalCents': 300000,
        'installmentsCount': 1,
      });

      expect(controller.form.control('installmentsCount').invalid, isTrue);
      expect(controller.form.valid, isFalse);
    });
  });

  group('operações', () {
    late ExpenseController controller;
    late SelectedMonthService month;
    final geladeira = ExpenseModel.fromJson(geladeiraJson);

    ExpenseController build() => ExpenseController(
      repository: repository,
      cardRepository: cards,
      tagRepository: tags,
      selectedMonth: month,
      nav: nav,
    );

    setUp(() {
      month = SelectedMonthService();
      controller = build();
    });
    tearDown(() {
      controller.dispose();
      month.dispose();
    });

    test('reparcelamento manda os dois totais e o mês', () async {
      await controller.reschedule(
        geladeira.id,
        newTotalCents: 400000,
        newInstallmentsCount: 12,
        fromMonth: '2026-05',
      );

      verify(
        () => repository.reschedule(
          geladeira.id,
          newTotalCents: 400000,
          newInstallmentsCount: 12,
          fromMonth: '2026-05',
        ),
      ).called(1);
      // O diálogo e o detalhe: quem mostra o plano novo é a lista.
      verify(() => nav.pop()).called(2);
    });

    test('quitação manda só o mês', () async {
      await controller.settle(geladeira.id, fromMonth: '2026-09');

      verify(() => repository.settle(geladeira.id, fromMonth: '2026-09'))
          .called(1);
      verify(() => nav.pop()).called(2);
    });

    test('recusa do backend deixa o diálogo aberto', () async {
      repository = setupExpenseTestInjector(
        mock: expenseRepositoryMock(
          operations: const Error(
            DomainRuleFailure(message: 'Não há parcelas futuras para quitar'),
          ),
        ),
      );
      controller.dispose();
      controller = build();

      await controller.settle(geladeira.id, fromMonth: '2027-05');

      verifyNever(() => nav.pop());
    });
  });

  group('telas', () {
    Future<void> pumpDetail(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ExpenseDetailPage(
            expense: ExpenseModel.fromJson(geladeiraJson),
          ),
        ),
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
        MaterialApp(
          home: ExpenseFormPage(expense: ExpenseModel.fromJson(aluguelJson)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Parcelado'), findsNothing);
      expect(find.text('À vista'), findsNothing);
    });
  });
}
