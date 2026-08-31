import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:multiple_result/multiple_result.dart';
import 'package:se_controle_ai/core/errors/app_exception.dart';
import 'package:se_controle_ai/core/errors/failure.dart';
import 'package:se_controle_ai/data/models/credit_card_model.dart';
import 'package:se_controle_ai/features/credit_cards/controller/credit_card_form_controller.dart';

import '../../fixtures/credit_card_fixture.dart';
import '../../fixtures/mocks.dart';

void main() {
  late MockCreditCardRepository repository;
  late CreditCardFormController controller;

  setUp(() {
    repository = creditCardRepositoryMock();
    controller = CreditCardFormController(repository);
  });

  tearDown(() => controller.dispose());

  /// Preenche o formulário como a view faria.
  void fill({
    String name = 'Nubank',
    String? lastDigits,
    int closingDay = 10,
    int dueDay = 17,
    int? limitCents,
  }) {
    controller.control<String>(CreditCardFormController.name).value = name;
    controller.control<String>(CreditCardFormController.lastDigits).value =
        lastDigits;
    controller.control<int>(CreditCardFormController.closingDay).value =
        closingDay;
    controller.control<int>(CreditCardFormController.dueDay).value = dueDay;
    controller.control<int>(CreditCardFormController.limitCents).value =
        limitCents;
  }

  group('cadastro', () {
    test('está pronto na hora — não há GET a esperar', () async {
      await controller.start();

      expect(controller.ready.value, isTrue);
      expect(controller.isEditing, isFalse);
    });

    test('recusa submit vazio sem chamar o backend', () async {
      await controller.start();

      final id = await controller.submit();

      expect(id, isNull);
      // Marcar como tocado é o que faz a mensagem aparecer: campo nunca tocado
      // fica inválido e silencioso.
      expect(
        controller.control<String>(CreditCardFormController.name).touched,
        isTrue,
      );
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

    test('cria com os opcionais preenchidos', () async {
      await controller.start();
      fill(lastDigits: '4321', limitCents: 800000);

      final id = await controller.submit();

      expect(id, 'novo-cartao');
      verify(
        () => repository.create(
          name: 'Nubank',
          closingDay: 10,
          dueDay: 17,
          lastDigits: '4321',
          limitCents: 800000,
        ),
      ).called(1);
    });

    // Campo de dígitos vazio tem que virar null, e não `''`: o backend recusa
    // string de tamanho zero.
    test('opcional vazio vai como null, não como string vazia', () async {
      await controller.start();
      fill(lastDigits: '  ');

      await controller.submit();

      verify(
        () => repository.create(
          name: any(named: 'name'),
          closingDay: any(named: 'closingDay'),
          dueDay: any(named: 'dueDay'),
          lastDigits: null,
          limitCents: null,
        ),
      ).called(1);
    });

    test('nome vai sem espaço nas pontas', () async {
      await controller.start();
      fill(name: '  Nubank  ');

      await controller.submit();

      verify(
        () => repository.create(
          name: 'Nubank',
          closingDay: any(named: 'closingDay'),
          dueDay: any(named: 'dueDay'),
          lastDigits: any(named: 'lastDigits'),
          limitCents: any(named: 'limitCents'),
        ),
      ).called(1);
    });
  });

  group('dígitos', () {
    test('três dígitos são recusados localmente', () async {
      await controller.start();
      fill(lastDigits: '123');

      final id = await controller.submit();

      expect(id, isNull);
      expect(
        controller
            .control<String>(CreditCardFormController.lastDigits)
            .hasError(CreditCardFormController.fourDigitsError),
        isTrue,
      );
    });

    test('em branco é válido — o campo é opcional (CAR-01)', () async {
      await controller.start();
      fill();

      expect(controller.form.valid, isTrue);
    });
  });

  group('edição', () {
    test('busca o cartão e preenche os campos', () async {
      await controller.start(id: 'id-nubank');

      expect(controller.ready.value, isTrue);
      expect(controller.isEditing, isTrue);
      expect(
        controller.control<String>(CreditCardFormController.name).value,
        'Nubank',
      );
      expect(
        controller.control<String>(CreditCardFormController.lastDigits).value,
        '4321',
      );
      expect(
        controller.control<int>(CreditCardFormController.closingDay).value,
        10,
      );
      expect(
        controller.control<int>(CreditCardFormController.dueDay).value,
        17,
      );
      expect(
        controller.control<int>(CreditCardFormController.limitCents).value,
        800000,
      );
      // Campo vindo do backend não nasce em vermelho.
      expect(controller.form.touched, isFalse);
    });

    test('GET que falha não libera o formulário', () async {
      stubCreditCardDetail(
        repository,
        result: const Error(NotFoundFailure(message: 'Cartão não encontrado')),
      );

      await controller.start(id: 'id-que-sumiu');

      // Sem `ready`, a tela mostra o erro em vez de um formulário vazio que
      // salvaria em cima de dados que ninguém viu.
      expect(controller.ready.value, isFalse);
      expect(controller.generalFailure.value, isA<NotFoundFailure>());
    });

    test('retry refaz o GET e libera o formulário', () async {
      stubCreditCardDetail(
        repository,
        result: const Error(NetworkFailure(message: 'sem rede')),
      );
      await controller.start(id: 'id-nubank');
      expect(controller.ready.value, isFalse);

      stubCreditCardDetail(repository);
      await controller.retry();

      expect(controller.ready.value, isTrue);
      expect(controller.generalFailure.value, isNull);
    });
  });

  // O que esta fase tem de próprio. Cada caso aqui é uma linha do CAR-08.
  group('CAR-08 — o corpo do PATCH', () {
    setUp(() async {
      // Nubank: dígitos 4321, fecha 10, vence 17, limite 800000.
      await controller.start(id: 'id-nubank');
    });

    test('só o campo mexido entra no corpo', () async {
      controller.control<String>(CreditCardFormController.name).value =
          'Nubank roxo';

      final id = await controller.submit();

      expect(id, 'id-nubank');
      expect(capturedUpdateBody(repository), {'name': 'Nubank roxo'});
    });

    test('esvaziar o limite manda null, que é o que apaga', () async {
      controller.control<int>(CreditCardFormController.limitCents).value = null;

      await controller.submit();

      final body = capturedUpdateBody(repository);
      expect(body, {'limitCents': null});
      expect(body.containsKey('limitCents'), isTrue);
    });

    test('esvaziar os dígitos manda null', () async {
      controller.control<String>(CreditCardFormController.lastDigits).value =
          '';

      await controller.submit();

      expect(capturedUpdateBody(repository), {'lastDigits': null});
    });

    // A diferença que Ganhos nunca exigiu: os dois campos abaixo estão em null
    // no formulário e nenhum deles deve virar `null` no corpo, porque nenhum
    // tinha valor para apagar.
    test('opcional que já era vazio e continua vazio não entra', () async {
      stubCreditCardDetail(
        repository,
        result: Success(CreditCardModel.fromJson(cartaoSimplesJson)),
      );
      await controller.start(id: 'id-simples');

      controller.control<String>(CreditCardFormController.name).value = 'Outro';

      await controller.submit();

      final body = capturedUpdateBody(repository);
      expect(body, {'name': 'Outro'});
      expect(body.containsKey('lastDigits'), isFalse);
      expect(body.containsKey('limitCents'), isFalse);
    });

    test('trocar o limite manda o valor novo', () async {
      controller.control<int>(CreditCardFormController.limitCents).value =
          150000;

      await controller.submit();

      expect(capturedUpdateBody(repository), {'limitCents': 150000});
    });

    test('mexer nos dois dias manda os dois', () async {
      controller.control<int>(CreditCardFormController.closingDay).value = 27;
      controller.control<int>(CreditCardFormController.dueDay).value = 5;

      await controller.submit();

      expect(capturedUpdateBody(repository), {'closingDay': 27, 'dueDay': 5});
    });

    test('reenviar o mesmo valor não conta como mudança', () async {
      controller.control<String>(CreditCardFormController.name).value =
          'Nubank';
      controller.control<int>(CreditCardFormController.limitCents).value =
          800000;

      final id = await controller.submit();

      // Nada mudou: nenhuma requisição, e a tela fecha como se tivesse salvo —
      // um PATCH de corpo vazio voltaria 400, e prender a pessoa na tela porque
      // ela não editou nada seria absurdo.
      expect(id, 'id-nubank');
      verifyNever(
        () => repository.update(
          any(),
          name: any(named: 'name'),
          closingDay: any(named: 'closingDay'),
          dueDay: any(named: 'dueDay'),
          lastDigits: any(named: 'lastDigits'),
          limitCents: any(named: 'limitCents'),
        ),
      );
    });

    test('espaço a mais no nome não conta como mudança', () async {
      controller.control<String>(CreditCardFormController.name).value =
          '  Nubank ';

      final id = await controller.submit();

      expect(id, 'id-nubank');
      verifyNever(
        () => repository.update(
          any(),
          name: any(named: 'name'),
          closingDay: any(named: 'closingDay'),
          dueDay: any(named: 'dueDay'),
          lastDigits: any(named: 'lastDigits'),
          limitCents: any(named: 'limitCents'),
        ),
      );
    });
  });

  group('recusa do backend', () {
    test('400 com path de campo vira erro do campo', () async {
      stubCreditCardOperations(
        repository,
        createResult: const Error(
          ValidationFailure(
            message: 'Dados inválidos',
            issues: [
              FieldIssue(
                path: 'lastDigits',
                message: 'Informe exatamente 4 dígitos',
              ),
            ],
          ),
        ),
      );
      await controller.start();
      fill(lastDigits: '4321');

      final id = await controller.submit();

      expect(id, isNull);
      expect(
        controller
            .control<String>(CreditCardFormController.lastDigits)
            .errors[CreditCardFormController.backendError],
        'Informe exatamente 4 dígitos',
      );
      // Erro de campo não vira snackbar: a mensagem já está embaixo do campo.
      expect(controller.generalFailure.value, isNull);
    });

    // O 400 de corpo vazio chega com `path` vazio, que não é campo nenhum.
    test('400 com path vazio sobe como falha geral', () async {
      stubCreditCardOperations(
        repository,
        createResult: const Error(
          ValidationFailure(
            message: 'Dados inválidos',
            issues: [
              FieldIssue(
                path: '',
                message: 'Informe ao menos um campo para atualizar',
              ),
            ],
          ),
        ),
      );
      await controller.start();
      fill();

      final id = await controller.submit();

      expect(id, isNull);
      expect(controller.generalFailure.value, isA<ValidationFailure>());
    });

    test('falha de rede sobe como falha geral', () async {
      stubCreditCardOperations(
        repository,
        createResult: const Error(NetworkFailure(message: 'sem rede')),
      );
      await controller.start();
      fill();

      expect(await controller.submit(), isNull);
      expect(controller.generalFailure.value, isA<NetworkFailure>());
    });

    test('saving sobe durante o envio e desce depois', () async {
      final segura = Completer<void>();
      stubCreditCardOperations(repository, pendenteAte: segura.future);
      await controller.start();
      fill();

      final pending = controller.submit();

      expect(controller.saving.value, isTrue);
      segura.complete();
      await pending;
      expect(controller.saving.value, isFalse);
    });
  });
}
