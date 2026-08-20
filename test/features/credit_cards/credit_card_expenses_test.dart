import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:multiple_result/multiple_result.dart';
import 'package:se_controle_ai/core/errors/failure.dart';
import 'package:se_controle_ai/core/shared/view_state.dart';
import 'package:se_controle_ai/core/utils/month.dart';
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
    late CreditCardExpensesController controller;

    setUp(() => controller = CreditCardExpensesController(expenses, cards));
    tearDown(() => controller.dispose());

    test('busca o cartão e as duas listas', () async {
      await controller.start('cartao-1');

      final state = controller.state.value;
      expect(state, isA<Loaded<CardWithExpenses>>());

      final view = (state as Loaded<CardWithExpenses>).data;
      expect(view.card.label, 'Nubank ••••4321');
      expect(view.expenses, hasLength(3));

      // O cartão com competência, para o vencimento vir resolvido (CAR-03).
      verify(() => cards.getById('cartao-1', month: Month.current())).called(1);
      // Uma lista sem competência — tudo que existe no cartão — e outra com,
      // que é a que traz valor preenchido para somar a fatura.
      verify(
        () => expenses.list(
          creditCardId: 'cartao-1',
          month: null,
          type: any(named: 'type'),
          paymentMethod: any(named: 'paymentMethod'),
        ),
      ).called(1);
      verify(
        () => expenses.list(
          creditCardId: 'cartao-1',
          month: Month.current(),
          type: any(named: 'type'),
          paymentMethod: any(named: 'paymentMethod'),
        ),
      ).called(1);
    });

    // O total não pode sair da lista sem competência: lá `amountCents` vem
    // null, e num parcelado o valor do mês nem está no histórico.
    test(
      'a fatura do mês soma o amountCents da lista com competência',
      () async {
        when(
          () => expenses.list(
            creditCardId: any(named: 'creditCardId'),
            month: Month.current(),
            type: any(named: 'type'),
            paymentMethod: any(named: 'paymentMethod'),
          ),
        ).thenAnswer(
          (_) async => Success([
            ExpenseModel.fromJson({...youtubeJson, 'amountCents': 2490}),
            ExpenseModel.fromJson({...presenteJson, 'amountCents': 18000}),
          ]),
        );

        await controller.start('cartao-1');

        final view = (controller.state.value as Loaded<CardWithExpenses>).data;
        expect(view.monthTotalCents, 20490);
      },
    );

    test('falha em qualquer das três buscas vira Failed', () async {
      stubExpenseList(
        expenses,
        result: const Error(NetworkFailure(message: 'sem rede')),
      );

      await controller.start('cartao-1');

      expect(controller.state.value, isA<Failed<CardWithExpenses>>());
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

    testWidgets('lista os gastos lançados no cartão', (tester) async {
      await pump(tester);

      expect(find.text('Lançados neste cartão'), findsOneWidget);
      expect(find.text('Aluguel'), findsOneWidget);
      expect(find.text('Youtube Music'), findsOneWidget);
    });

    testWidgets('cartão sem gasto explica o que aparece ali', (tester) async {
      setupExpenseTestInjector(
        mock: expenseRepositoryMock(list: const Success([])),
      );

      await pump(tester);

      expect(find.text('Nada lançado neste cartão'), findsOneWidget);
    });

    testWidgets('falha mostra o card de erro', (tester) async {
      setupExpenseTestInjector(
        mock: expenseRepositoryMock(
          list: const Error(NetworkFailure(message: 'Sem conexão.')),
        ),
      );

      await pump(tester);

      expect(find.text('Sem conexão.'), findsOneWidget);
    });

    // A edição saiu do toque na lista e virou o lápis daqui; sem ele, editar um
    // cartão ficaria inalcançável.
    testWidgets('o lápis da barra existe para editar o cartão', (tester) async {
      await pump(tester);

      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    });
  });
}
