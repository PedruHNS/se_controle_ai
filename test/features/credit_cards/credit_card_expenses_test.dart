import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:multiple_result/multiple_result.dart';
import 'package:se_controle_ai/data/services/selected_month_service.dart';
import 'package:se_controle_ai/core/errors/failure.dart';
import 'package:se_controle_ai/core/shared/view_state.dart';
import 'package:se_controle_ai/core/utils/month_utils.dart';
import 'package:se_controle_ai/data/models/credit_card_bill_model.dart';
import 'package:se_controle_ai/data/models/expense_model.dart';
import 'package:se_controle_ai/features/credit_cards/controller/credit_card_expenses_controller.dart';
import 'package:se_controle_ai/features/credit_cards/view/credit_card_expenses_page.dart';

import '../../fixtures/expense_fixture.dart';
import '../../fixtures/mocks.dart';
import '../../fixtures/test_injector.dart';

void main() {
  late MockExpenseRepository expenses;
  late MockCreditCardRepository cards;

  setUp(() {
    cards = setupCreditCardTestInjector();
    expenses = setupExpenseTestInjector();
  });

  group('controller', () {
    late SelectedMonthService month;
    late CreditCardExpensesController controller;

    setUp(() {
      month = SelectedMonthService();
      controller = CreditCardExpensesController(
        repository: cards,
        selectedMonth: month,
      );
    });
    tearDown(() => controller.dispose());

    Future<void> start() async {
      controller.start('cartao-1');
      await pumpEventQueue();
    }

    test('busca a fatura do mês numa requisição só', () async {
      await start();

      final state = controller.state.value;
      expect(state, isA<Loaded<CreditCardBillModel>>());

      final view = (state as Loaded<CreditCardBillModel>).data;
      expect(view.card.label, 'Nubank ••••4321');
      expect(view.expenses, hasLength(3));

      verify(
        () => cards.getBill('cartao-1', month: SelectedMonthService.initial()),
      ).called(1);
    });

    // O ponto da mudança: a tela era duas rotas — o cartão e a lista de gastos
    // — juntadas no cliente. Uma tela, uma resposta.
    test('não pede mais o cartão e os gastos em rotas separadas', () async {
      await start();

      verifyNever(() => cards.getById(any(), month: any(named: 'month')));
      verifyNever(
        () => expenses.list(
          creditCardId: any(named: 'creditCardId'),
          month: any(named: 'month'),
          type: any(named: 'type'),
          paymentMethod: any(named: 'paymentMethod'),
        ),
      );
    });

    // O total vem pronto do backend: num parcelado o valor do mês não está no
    // histórico, está nas parcelas (GFX-09), e refazer a conta aqui seria a
    // mesma regra escrita em dois lugares que podem discordar.
    test('o total da fatura vem do backend, não é somado aqui', () async {
      stubCreditCardBill(
        cards,
        expenses: [
          ExpenseModel.fromJson({...youtubeJson, 'amountCents': 2490}),
          ExpenseModel.fromJson({...presenteJson, 'amountCents': 18000}),
        ],
      );

      await start();

      final view = (controller.state.value as Loaded<CreditCardBillModel>).data;
      expect(view.totalCents, 20490);
    });

    test('trocar a competência rebusca a fatura do novo mês', () async {
      await start();

      month.goToNext();
      await pumpEventQueue();

      verifyInOrder([
        () => cards.getBill('cartao-1', month: SelectedMonthService.initial()),
        () => cards.getBill(
          'cartao-1',
          month: MonthUtils.next(SelectedMonthService.initial()),
        ),
      ]);
    });

    test('o refresh rebusca a fatura', () async {
      await start();
      await controller.refresh(id: 'cartao-1');

      verify(
        () => cards.getBill('cartao-1', month: SelectedMonthService.initial()),
      ).called(2);
    });

    test('falha na busca vira Failed', () async {
      stubCreditCardBill(
        cards,
        result: const Error(NetworkFailure(message: 'sem rede')),
      );

      await start();

      expect(controller.state.value, isA<Failed<CreditCardBillModel>>());
    });
  });

  group('tela', () {
    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: CreditCardExpensesPage(id: 'cartao-1')),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('mostra o cartão no título e a fatura do mês', (tester) async {
      await pump(tester);

      expect(find.text('Nubank ••••4321'), findsOneWidget);
      expect(find.textContaining('Fatura de'), findsOneWidget);
      expect(find.textContaining('Fecha dia 10'), findsOneWidget);
    });

    testWidgets('lista o que é cobrado nesta fatura', (tester) async {
      await pump(tester);

      expect(find.text('Nesta fatura'), findsOneWidget);
      expect(find.text('Aluguel'), findsOneWidget);
      expect(find.text('Youtube Music'), findsOneWidget);
    });

    testWidgets('cartão sem gasto explica o que aparece ali', (tester) async {
      stubCreditCardBill(cards, expenses: const []);

      await pump(tester);

      expect(find.text('Nada nesta fatura'), findsOneWidget);
    });

    testWidgets('falha mostra o card de erro', (tester) async {
      stubCreditCardBill(
        cards,
        result: const Error(NetworkFailure(message: 'Sem conexão.')),
      );

      await pump(tester);

      expect(find.text('Sem conexão.'), findsOneWidget);
    });

    // A edição saiu do toque na lista e virou o lápis daqui; sem ele, editar um
    // cartão ficaria inalcançável.
    // O lápis saiu da barra: editar o cadastro passou para o menu do card, na
    // lista. Esta tela é a fatura do mês, não o cadastro do cartão — e uma
    // porta só evita a dúvida de qual das duas é a certa.
    testWidgets('a barra não oferece editar o cartão', (tester) async {
      await pump(tester);

      expect(find.byIcon(Icons.edit_outlined), findsNothing);
    });
  });
}
