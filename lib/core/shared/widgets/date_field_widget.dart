import 'package:flutter/material.dart';
import 'package:reactive_forms/reactive_forms.dart';

import '../../utils/iso_date_utils.dart';

/// Seletor de data `YYYY-MM-DD` por calendário, ligado a um
/// `FormControl<String>`.
///
/// Diferente do [MonthFieldWidget] e do [DayFieldWidget], que são setas: aqui a
/// pessoa escolhe entre trinta e poucos valores e quer ver o dia da semana ao
/// lado do número — "foi no sábado" é como se lembra de uma compra. Setas
/// dariam o valor certo sem responder essa pergunta.
///
/// **Um ano para trás e um para frente.** O futuro esteve apagado por um dia,
/// com o argumento de que ninguém compra amanhã — e ele caiu quando o seletor
/// de competência saiu do formulário: sem o futuro, não haveria como lançar o
/// IPVA de janeiro, e o campo que permitia isso é justamente o que sumiu. O
/// teto existe para um deslize de rolagem não cadastrar em 2031.
///
/// Antes disso, a primeira versão era presa ao mês da competência
/// (10/09/2026). A prisão vinha de a data ter que combinar com o mês escolhido
/// à mão; hoje é o contrário — **é o dia que decide a competência**, então
/// prender o calendário a ela bloquearia exatamente a compra que precisa
/// mudá-la.
///
/// Sem valor, mostra o texto de vazio. O `X` que limpa a escolha só aparece
/// quando [clearable] — num campo obrigatório ele não tem o que significar,
/// e serviria só para deixar o formulário inválido de propósito.
///
/// `DateTime` aparece só aqui dentro, entre abrir o picker e ler o retorno. O
/// control guarda string ISO, como manda a decisão 3 — é `DateTime` circulando
/// que faz data andar um dia para trás.
class DateFieldWidget extends StatelessWidget {
  const DateFieldWidget({
    required this.formControlName,
    required this.label,
    this.helperText,
    this.emptyText = 'Não informado',
    this.clearable = true,
    this.monthsBack = 12,
    this.monthsAhead = 12,
    super.key,
  });

  final String formControlName;
  final String label;

  final String? helperText;

  /// O que aparece quando ninguém escolheu data. Não é `hintText` de propósito:
  /// o campo não é digitável, então isto é conteúdo, não dica.
  final String emptyText;

  /// Oferece o `X` que devolve o campo ao vazio.
  final bool clearable;

  /// Quantos meses para trás o calendário abre, contando o corrente. Doze
  /// cobre a compra esquecida do ano.
  final int monthsBack;

  /// Quantos meses para frente, contando o corrente. Doze cobre o que dá para
  /// planejar sem virar chute.
  final int monthsAhead;

  /// Do primeiro dia do mês mais antigo ao último dia do mês mais distante.
  ///
  /// Mês negativo ou maior que doze é conta que o próprio `DateTime` resolve
  /// virando o ano, e o dia 0 de um mês é o último do anterior: as duas pontas
  /// saem sem tabela de dias e sem caso especial para fevereiro.
  (DateTime first, DateTime last) _bounds() {
    final now = DateTime.now();

    return (
      DateTime(now.year, now.month - (monthsBack - 1), 1),
      DateTime(now.year, now.month + monthsAhead, 0),
    );
  }

  static String _toIso(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// Onde o calendário abre: no dia já escolhido, se ele estiver no intervalo,
  /// senão hoje — que é o palpite certo na esmagadora maioria dos casos, e
  /// fica no meio do intervalo agora que ele vai para os dois lados. Abrir num
  /// dia de fora é assertion do Flutter, não campo vazio.
  static DateTime _initial(String? value, DateTime first, DateTime last) {
    if (value != null && value.length == 10) {
      final chosen = DateTime.tryParse(value);
      if (chosen != null && !chosen.isBefore(first) && !chosen.isAfter(last)) {
        return chosen;
      }
    }

    final now = DateTime.now();

    return DateTime(now.year, now.month, now.day);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (first, last) = _bounds();

    return ReactiveFormField<String, String>(
      formControlName: formControlName,
      validationMessages: {
        ValidationMessage.required: (_) => 'Informe o dia.',
        'backend': (error) => '$error',
      },
      builder: (field) {
        final value = field.value;
        final hasDate = value != null && value.length == 10;

        Future<void> pick() async {
          final chosen = await showDatePicker(
            context: context,
            initialDate: _initial(value, first, last),
            firstDate: first,
            lastDate: last,
            helpText: 'Dia da compra',
            cancelText: 'Cancelar',
            confirmText: 'Confirmar',
            fieldLabelText: 'Dia da compra',
          );

          if (chosen != null) field.didChange(_toIso(chosen));
        }

        return InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            errorText: field.errorText,
            helperText: helperText ?? 'Até um ano para trás ou para frente',
            helperMaxLines: 2,
            border: const OutlineInputBorder(),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  hasDate ? IsoDateUtils.fullLabel(value) : emptyText,
                  style: hasDate
                      ? theme.textTheme.titleMedium
                      : theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                ),
              ),
              if (hasDate && clearable)
                IconButton(
                  tooltip: 'Limpar a data',
                  icon: const Icon(Icons.close),
                  onPressed: () => field.didChange(null),
                ),
              IconButton(
                tooltip: 'Escolher o dia',
                icon: const Icon(Icons.calendar_today_outlined),
                onPressed: pick,
              ),
            ],
          ),
        );
      },
    );
  }
}
