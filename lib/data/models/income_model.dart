import '../../core/utils/month.dart';
import 'amount_version_model.dart';

/// Um ganho: salário, freela, 13º, aluguel recebido.
///
/// O valor não é um campo do ganho, é uma vigência — por isso [history]. O
/// [amountCents] é o valor **do mês consultado** quando a busca leva `?month`,
/// e o da vigência mais recente quando não leva (GAN-10 da spec).
class IncomeModel {
  const IncomeModel({
    required this.id,
    required this.description,
    required this.recurring,
    required this.startMonth,
    required this.endMonth,
    required this.amountCents,
    required this.history,
  });

  final String id;
  final String description;

  /// Segue até ser encerrado. Falso em ganho de mês único (13º, freela) e
  /// também depois de um encerramento.
  final bool recurring;

  /// Primeira competência do ganho, `YYYY-MM`.
  final String startMonth;

  /// Última competência recebida. Null enquanto o ganho está em aberto.
  final String? endMonth;

  final int amountCents;

  /// Da vigência mais antiga para a mais nova, como o backend devolve.
  final List<AmountVersionModel> history;

  /// Tem data de fim. É o que decide se as operações de dinheiro ainda são
  /// possíveis: ganho encerrado não aceita reajuste, correção nem novo
  /// encerramento (GAN-08).
  ///
  /// **Não** é o mesmo que "não entra mais": um ganho de mês único nasce com
  /// `endMonth` preenchido e ainda assim entra no mês dele. Para essa pergunta
  /// use [endedBefore].
  bool get isClosed => endMonth != null;

  /// Começa e termina na mesma competência: venda, presente, 13º, freela.
  ///
  /// Um ganho recorrente encerrado no próprio mês de início cai aqui também, e
  /// tudo bem — a partir do payload os dois são a mesma coisa, e a tela diz o
  /// mesmo sobre os dois: entra só naquele mês.
  bool get isSingleMonth => endMonth != null && endMonth == startMonth;

  /// Já acabou **antes** de [month] — aí sim "não entra mais". É o que a lista
  /// usa para marcar o ganho como encerrado, em vez de [isClosed], que marcaria
  /// a venda de agosto como encerrada já em agosto.
  bool endedBefore(String month) {
    final end = endMonth;
    return end != null && Month.isBefore(end, month);
  }

  /// O valor vigente em [month], lido do histórico. Null quando o ganho não
  /// vigia naquela competência.
  ///
  /// Existe porque [amountCents] é o valor da vigência **mais recente** quando
  /// a busca vem sem `?month` (GAN-10) — e a mais recente pode ser uma que só
  /// começa no mês que vem, se houver reajuste agendado. Somar [amountCents]
  /// para saber quanto entra este mês daria um total diferente do da home.
  int? amountCentsIn(String month) {
    for (final version in history) {
      final started = Month.compare(month, version.validFrom) >= 0;
      final to = version.validTo;
      final notFinished = to == null || Month.compare(month, to) <= 0;
      if (started && notFinished) return version.amountCents;
    }
    return null;
  }

  /// Entra em [month]?
  bool isActiveIn(String month) => amountCentsIn(month) != null;

  /// A vigência que ainda está aberta, se houver.
  AmountVersionModel? get currentVersion {
    for (final version in history.reversed) {
      if (version.isOpen) return version;
    }
    return null;
  }

  /// Houve pelo menos um reajuste — a tela só mostra a linha do tempo quando
  /// existe mais de uma vigência para comparar.
  bool get hasAdjustments => history.length > 1;

  factory IncomeModel.fromJson(Map<String, dynamic> json) => IncomeModel(
    id: json['id'] as String,
    description: json['description'] as String,
    recurring: json['recurring'] as bool,
    startMonth: json['startMonth'] as String,
    endMonth: json['endMonth'] as String?,
    amountCents: json['amountCents'] as int,
    history: (json['history'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(AmountVersionModel.fromJson)
        .toList(growable: false),
  );
}
