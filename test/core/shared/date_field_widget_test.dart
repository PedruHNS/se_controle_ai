import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:se_controle_ai/core/shared/widgets/date_field_widget.dart';

/// Os limites do calendário são conferidos no próprio `DatePickerDialog`, e
/// não tentando tocar num dia de fora: um dia desabilitado engole o toque em
/// silêncio, e o "Confirmar" ainda devolveria a data inicial — o teste passaria
/// sem provar nada.
void main() {
  late FormGroup form;

  setUp(() {
    form = FormGroup({'spentAt': FormControl<String>()});
  });

  tearDown(() => form.dispose());

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: ReactiveForm(
          formGroup: form,
          child: const DateFieldWidget(
            formControlName: 'spentAt',
            label: 'Dia da compra (opcional)',
          ),
        ),
      ),
    ),
  );

  Future<DatePickerDialog> abrirCalendario(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Escolher o dia'));
    await tester.pumpAndSettle();
    return tester.widget<DatePickerDialog>(find.byType(DatePickerDialog));
  }

  DateTime hoje() {
    final agora = DateTime.now();
    return DateTime(agora.year, agora.month, agora.day);
  }

  // O futuro é o que permite lançar o IPVA de janeiro sem seletor de mês.
  testWidgets('vai até o último dia de um ano à frente', (tester) async {
    await pump(tester);

    final esperado = DateTime(hoje().year, hoje().month + 12, 0);

    expect((await abrirCalendario(tester)).lastDate, esperado);
  });

  testWidgets('abre um ano para trás, no primeiro dia do mês', (tester) async {
    await pump(tester);

    final esperado = DateTime(hoje().year, hoje().month - 11, 1);

    expect((await abrirCalendario(tester)).firstDate, esperado);
  });

  // Sem teto, um deslize de rolagem cadastra em 2031.
  testWidgets('o intervalo tem as duas pontas', (tester) async {
    await pump(tester);

    final dialog = await abrirCalendario(tester);

    expect(dialog.firstDate.isBefore(hoje()), isTrue);
    expect(dialog.lastDate.isAfter(hoje()), isTrue);
    expect(dialog.lastDate.difference(dialog.firstDate).inDays, lessThan(732));
  });

  // Sem data escolhida o calendário abre em hoje. Abrir numa ponta do
  // intervalo faria a pessoa rolar doze meses para chegar ao caso comum, que é
  // "comprei ontem".
  testWidgets('sem escolha, abre em hoje', (tester) async {
    await pump(tester);

    expect((await abrirCalendario(tester)).initialDate, hoje());
  });

  testWidgets('com data escolhida, abre nela', (tester) async {
    final escolhido = hoje().subtract(const Duration(days: 40));
    form.control('spentAt').value =
        '${escolhido.year.toString().padLeft(4, '0')}-'
        '${escolhido.month.toString().padLeft(2, '0')}-'
        '${escolhido.day.toString().padLeft(2, '0')}';

    await pump(tester);

    expect((await abrirCalendario(tester)).initialDate, escolhido);
  });

  testWidgets('o campo vazio diz que não foi informado', (tester) async {
    await pump(tester);

    expect(find.text('Não informado'), findsOneWidget);
    expect(find.text('Até um ano para trás ou para frente'), findsOneWidget);
    // Sem data escolhida não há o que limpar, e o X não aparece.
    expect(find.byTooltip('Limpar a data'), findsNothing);
  });

  testWidgets('o texto de apoio de quem chama substitui o padrão', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReactiveForm(
            formGroup: form,
            child: const DateFieldWidget(
              formControlName: 'spentAt',
              label: 'Dia da compra (opcional)',
              helperText: 'Fecha dia 10 · entra na fatura de outubro 2026',
            ),
          ),
        ),
      ),
    );

    expect(
      find.text('Fecha dia 10 · entra na fatura de outubro 2026'),
      findsOneWidget,
    );
    expect(find.text('Até um ano para trás ou para frente'), findsNothing);
  });
}
