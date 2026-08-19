import 'package:flutter_test/flutter_test.dart';
import 'package:se_controle_ai/core/shared/patch.dart';

void main() {
  group('writeTo', () {
    test('keep não escreve a chave — é o "campo ausente" do CAR-08', () {
      final body = <String, dynamic>{};
      const Patch<int>.keep().writeTo(body, 'limitCents');

      expect(body, isEmpty);
      expect(body.containsKey('limitCents'), isFalse);
    });

    test('clear escreve null — é o "limpa" do CAR-08', () {
      final body = <String, dynamic>{};
      const Patch<int>.clear().writeTo(body, 'limitCents');

      expect(body, {'limitCents': null});
      expect(body.containsKey('limitCents'), isTrue);
    });

    test('to escreve o valor', () {
      final body = <String, dynamic>{};
      const Patch<int>.to(150000).writeTo(body, 'limitCents');

      expect(body, {'limitCents': 150000});
    });
  });

  group('diff', () {
    test('valor igual ao anterior não mexe no campo', () {
      expect(Patch<int>.diff(800000, 800000), const Patch<int>.keep());
      expect(Patch<String>.diff(null, null), const Patch<String>.keep());
    });

    test('valor novo troca', () {
      expect(Patch<int>.diff(150000, 800000), const Patch<int>.to(150000));
    });

    test('preenche o que estava vazio', () {
      expect(Patch<String>.diff('4321', null), const Patch<String>.to('4321'));
    });

    // O caso que motiva a classe existir: os dois chegam do formulário como
    // null, e só o valor anterior os separa.
    test('esvaziar o que tinha valor limpa, e não mexer não faz nada', () {
      expect(Patch<int>.diff(null, 800000), const Patch<int>.clear());
      expect(Patch<int>.diff(null, null), const Patch<int>.keep());
    });
  });

  group('changesSomething', () {
    test('só keep não muda nada', () {
      expect(const Patch<int>.keep().changesSomething, isFalse);
      expect(const Patch<int>.clear().changesSomething, isTrue);
      expect(const Patch<int>.to(1).changesSomething, isTrue);
    });
  });

  group('igualdade', () {
    // Sem isto, `verify(() => mock.update(id, limitCents: Patch.to(150000)))`
    // não casaria: o mocktail compara os argumentos por igualdade.
    test('to compara por valor', () {
      expect(const Patch<int>.to(10), const Patch<int>.to(10));
      expect(const Patch<int>.to(10), isNot(const Patch<int>.to(11)));
      expect(const Patch<int>.to(10), isNot(const Patch<int>.keep()));
    });

    test('keep e clear são distintos entre si', () {
      expect(const Patch<int>.keep(), const Patch<int>.keep());
      expect(const Patch<int>.keep(), isNot(const Patch<int>.clear()));
    });
  });
}
