import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:multiple_result/multiple_result.dart';
import 'package:se_controle_ai/core/errors/failure.dart';
import 'package:se_controle_ai/core/shared/widgets/day_field_widget.dart';
import 'package:se_controle_ai/features/credit_cards/view/credit_card_form_page.dart';
import 'package:se_controle_ai/features/credit_cards/view/credit_card_list_page.dart';

import '../../fixtures/mocks.dart';
import '../../fixtures/test_injector.dart';

void main() {
  late MockCreditCardRepository repository;

  setUp(() {
    repository = setupCreditCardTestInjector();
  });

  Future<void> pumpList(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: CreditCardListPage()));
    await tester.pumpAndSettle();
  }

  Future<void> pumpForm(WidgetTester tester, {String? id}) async {
    await tester.pumpWidget(MaterialApp(home: CreditCardFormPage(id: id)));
    await tester.pumpAndSettle();
  }

  group('lista', () {
    testWidgets('mostra os cartões com fechamento e vencimento', (
      tester,
    ) async {
      await pumpList(tester);

      expect(find.text('Nubank ••••4321'), findsOneWidget);
      // O vencimento sai do `dueDate` da competência, não do dia solto.
      expect(find.text('Fecha dia 10 · vence 17/08'), findsOneWidget);
      expect(find.text('Cartão de teste'), findsOneWidget);
      expect(find.text('Fecha dia 27 · vence 05/04'), findsOneWidget);
    });

    testWidgets('cartão sem limite diz que não tem, em vez de mostrar zero', (
      tester,
    ) async {
      await pumpList(tester);

      expect(find.text(r'R$ 8.000'), findsOneWidget);
      expect(find.text('sem limite'), findsOneWidget);
    });

    testWidgets('lista vazia convida a cadastrar', (tester) async {
      setupCreditCardTestInjector(
        mock: creditCardRepositoryMock(list: const Success([])),
      );

      await pumpList(tester);

      expect(find.text('Nenhum cartão cadastrado'), findsOneWidget);
      expect(
        find.text('Cadastre um para poder lançar gasto no cartão.'),
        findsOneWidget,
      );
    });

    testWidgets('falha mostra o card de erro', (tester) async {
      setupCreditCardTestInjector(
        mock: creditCardRepositoryMock(
          list: const Error(NetworkFailure(message: 'sem rede')),
        ),
      );

      await pumpList(tester);

      expect(find.text('sem rede'), findsOneWidget);
    });
  });

  group('exclusão', () {
    testWidgets('pede confirmação antes de excluir', (tester) async {
      await pumpList(tester);

      await tester.tap(find.byTooltip('Excluir cartão').first);
      await tester.pumpAndSettle();

      expect(find.text('Excluir cartão'), findsOneWidget);
      expect(find.text('Nubank ••••4321 sai do cadastro.'), findsOneWidget);
      verifyNever(() => repository.delete(any()));

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      verifyNever(() => repository.delete(any()));
    });

    testWidgets('confirmar exclui e fecha o diálogo', (tester) async {
      await pumpList(tester);

      await tester.tap(find.byTooltip('Excluir cartão').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();

      verify(
        () => repository.delete('39e95359-97f2-441c-bc26-f68a8821ae5a'),
      ).called(1);
      expect(find.text('Excluir'), findsNothing);
    });

    // CAR-07. O erro fica no diálogo porque é resposta à pergunta que ele fez, e
    // o cartão continua na lista de trás, intacto.
    testWidgets('409 de gastos vinculados aparece dentro do diálogo', (
      tester,
    ) async {
      setupCreditCardTestInjector(
        mock: creditCardRepositoryMock(
          operations: const Error(
            ConflictFailure(
              message:
                  'Cartão possui gastos vinculados e não pode ser excluído',
            ),
          ),
        ),
      );

      await pumpList(tester);
      await tester.tap(find.byTooltip('Excluir cartão').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();

      expect(
        find.text('Cartão possui gastos vinculados e não pode ser excluído'),
        findsOneWidget,
      );
      // O diálogo continua aberto, e o cartão continua na lista.
      expect(find.text('Excluir'), findsOneWidget);
      expect(find.text('Nubank ••••4321'), findsOneWidget);
    });
  });

  group('formulário de cadastro', () {
    testWidgets('abre vazio, com os dois seletores de dia', (tester) async {
      await pumpForm(tester);

      expect(find.text('Novo cartão'), findsOneWidget);
      expect(find.byType(DayFieldWidget), findsNWidgets(2));
      expect(find.text('Fechamento'), findsOneWidget);
      expect(find.text('Vencimento'), findsOneWidget);
    });

    testWidgets('submit vazio mostra a mensagem e não chama o backend', (
      tester,
    ) async {
      await pumpForm(tester);

      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(find.text('Informe o nome do cartão.'), findsOneWidget);
      verifyNever(
        () => repository.create(
          name: any(named: 'name'),
          closingDay: any(named: 'closingDay'),
          dueDay: any(named: 'dueDay'),
          lastDigits: any(named: 'lastDigits'),
          limitCents: any(named: 'limitCents'),
        ),
      );
    });

    testWidgets('cadastra com nome, dias pelas setas e limite digitado', (
      tester,
    ) async {
      await pumpForm(tester);

      await tester.enterText(find.byType(TextField).first, 'Inter');

      // Fechamento: do dia 1 para o dia 2.
      await tester.tap(
        find
            .descendant(
              of: find.byType(DayFieldWidget).first,
              matching: find.byTooltip('Próximo dia'),
            )
            .first,
      );
      await tester.pumpAndSettle();

      // Limite: o campo de dinheiro é o último TextField da tela.
      await tester.enterText(find.byType(TextField).last, '1500,00');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      verify(
        () => repository.create(
          name: 'Inter',
          closingDay: 2,
          dueDay: 10,
          lastDigits: null,
          limitCents: 150000,
        ),
      ).called(1);
    });

    // O helper é a única explicação do CAR-03 que a pessoa vê antes de a fatura
    // existir.
    testWidgets('o helper do vencimento explica em que mês a fatura cai', (
      tester,
    ) async {
      await pumpForm(tester);

      // Nasce fechando dia 1 e vencendo dia 10: vence no próprio mês.
      expect(find.textContaining('vence no próprio mês'), findsOneWidget);

      // Puxa o fechamento para trás do vencimento: dia 1 → dia 31.
      await tester.tap(
        find
            .descendant(
              of: find.byType(DayFieldWidget).first,
              matching: find.byTooltip('Dia anterior'),
            )
            .first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Dia 31'), findsOneWidget);
      expect(find.textContaining('vence no mês seguinte'), findsOneWidget);
    });

    testWidgets('três dígitos são recusados no campo', (tester) async {
      await pumpForm(tester);

      await tester.enterText(find.byType(TextField).first, 'Inter');
      await tester.enterText(find.byType(TextField).at(1), '123');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(
        find.text('Informe os quatro últimos dígitos, ou deixe em branco.'),
        findsOneWidget,
      );
    });

    testWidgets('falha de rede vira snackbar', (tester) async {
      setupCreditCardTestInjector(
        mock: creditCardRepositoryMock(
          create: const Error(NetworkFailure(message: 'sem rede')),
        ),
      );

      await pumpForm(tester);
      await tester.enterText(find.byType(TextField).first, 'Inter');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(SnackBar, 'sem rede'), findsOneWidget);
    });
  });

  group('formulário de edição', () {
    testWidgets('abre preenchido com o cartão', (tester) async {
      await pumpForm(tester, id: 'id-nubank');

      expect(find.text('Editar cartão'), findsOneWidget);
      expect(find.text('Nubank'), findsOneWidget);
      expect(find.text('4321'), findsOneWidget);
      expect(find.text('Dia 10'), findsOneWidget);
      expect(find.text('Dia 17'), findsOneWidget);
      expect(find.text('8.000,00'), findsOneWidget);
    });

    testWidgets('GET que falha mostra erro, e não formulário', (tester) async {
      setupCreditCardTestInjector(
        mock: creditCardRepositoryMock(
          detail: const Error(
            NotFoundFailure(message: 'Cartão não encontrado'),
          ),
        ),
      );

      await pumpForm(tester, id: 'id-que-sumiu');

      expect(find.text('Cartão não encontrado'), findsOneWidget);
      expect(find.text('Salvar'), findsNothing);
    });

    testWidgets('editar só o nome manda só o nome (CAR-08)', (tester) async {
      await pumpForm(tester, id: 'id-nubank');

      await tester.enterText(find.byType(TextField).first, 'Nubank roxo');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(capturedUpdateBody(repository), {'name': 'Nubank roxo'});
    });

    testWidgets('apagar o limite na tela manda null (CAR-08)', (tester) async {
      await pumpForm(tester, id: 'id-nubank');

      await tester.enterText(find.byType(TextField).last, '');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      final body = capturedUpdateBody(repository);
      expect(body, {'limitCents': null});
      expect(body.containsKey('limitCents'), isTrue);
    });

    testWidgets('abrir e fechar sem mexer não manda requisição', (
      tester,
    ) async {
      await pumpForm(tester, id: 'id-nubank');

      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(updateBodies(repository), isEmpty);
    });
  });
}
