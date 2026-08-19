import 'package:flutter_test/flutter_test.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:se_controle_ai/core/shared/forms/money_value_accessor.dart';

void main() {
  late MoneyValueAccessor accessor;

  setUp(() => accessor = MoneyValueAccessor());

  group('texto digitado → centavos', () {
    test('lê as formas que aparecem na prática', () {
      expect(accessor.viewToModelValue('1800'), 180000);
      expect(accessor.viewToModelValue('1.800'), 180000);
      expect(accessor.viewToModelValue('1800,50'), 180050);
      expect(accessor.viewToModelValue(r'R$ 1.800,00'), 180000);
    });

    test('campo vazio é null, não zero', () {
      // Zero passaria pelo required e seria recusado só no min — a mensagem
      // certa para campo em branco é "informe o valor".
      expect(accessor.viewToModelValue(''), isNull);
      expect(accessor.viewToModelValue('   '), isNull);
      expect(accessor.viewToModelValue(null), isNull);
    });

    test('centavo digitado não passa por double', () {
      // 0,145 não existe exato em binário: via double viraria 14 centavos.
      expect(accessor.viewToModelValue('0,145'), 14);
      expect(accessor.viewToModelValue('8,70'), 870);
    });
  });

  group('centavos → texto do campo', () {
    test('formata sem o símbolo, que já é prefixo do input', () {
      expect(accessor.modelToViewValue(180000), '1.800,00');
      expect(accessor.modelToViewValue(4550), '45,50');
    });

    test('null vira campo vazio', () {
      expect(accessor.modelToViewValue(null), '');
    });
  });

  test('digitar não é interrompido por reformatação', () async {
    // O control só empurra valor de volta para o campo quando a mudança não
    // veio dele. Sem essa guarda, digitar "50" viraria "0,50" no meio da
    // palavra e o campo ficaria impossível de usar.
    final control = FormControl<int>();
    final views = <String?>[];
    accessor.registerControl(control, onChange: views.add);

    accessor.updateModel('5000');
    // O aviso ao campo sai por stream, então só chega na próxima microtask —
    // sem o await, a lista estaria vazia por atraso e não por causa da guarda.
    await Future<void>.delayed(Duration.zero);

    expect(control.value, 500000);
    expect(
      views,
      isEmpty,
      reason: 'devolveu texto para o campo enquanto digitava',
    );

    // Já uma mudança feita em código chega formatada — é o que pré-preenche o
    // diálogo de correção.
    control.updateValue(480000);
    await Future<void>.delayed(Duration.zero);

    expect(views, ['4.800,00']);
  });
}
