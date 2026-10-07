import '../../data/models/amount_version_model.dart';
import 'month_utils.dart';

/// As contas sobre o histórico de vigências de um valor: quanto ele valia em
/// um mês, e qual vigência ainda está aberta.
///
/// Moram aqui, e não no `IncomeModel`, porque model não tem nada derivado — é a
/// regra em `.claude/rules/models.md`. Dos três destinos que a regra oferece,
/// este é o do meio: **a mesma regra serve a telas diferentes**. A lista de
/// ganhos usa o valor do mês para somar o que entra, e os diálogos de reajuste
/// e de encerramento usam a vigência aberta para achar o primeiro mês que o
/// backend aceitaria.
///
/// **Recebe o histórico, e não o ganho.** O gasto fixo guarda o mesmo `history`,
/// no mesmo formato (CONC-09 a CONC-12), e o `ExpenseModel` ainda carrega uma
/// cópia destas duas contas. Quando o `expenses` for alinhado à regra, a cópia
/// dele passa a chamar esta.
abstract final class AmountVersionUtils {
  /// O valor vigente em [month], lido de [history]. Null quando o histórico não
  /// cobre aquela competência.
  ///
  /// Existe porque o `amountCents` do ganho é o da vigência **mais recente**
  /// quando a busca vem sem `?month` (GAN-10) — e a mais recente pode ser uma
  /// que só começa no mês que vem, se houver reajuste agendado. Somar o campo
  /// direto para saber quanto entra este mês daria um total diferente do da
  /// home.
  static int? amountCentsIn(List<AmountVersionModel> history, String month) {
    for (final version in history) {
      final started = MonthUtils.compare(month, version.validFrom) >= 0;
      final to = version.validTo;
      final notFinished = to == null || MonthUtils.compare(month, to) <= 0;
      if (started && notFinished) return version.amountCents;
    }
    return null;
  }

  /// A vigência que ainda está aberta (`validTo` nulo), se houver. É dela que
  /// saem os limites dos diálogos de reajuste e de encerramento.
  ///
  /// Ganho encerrado, e ganho de mês único, não têm nenhuma.
  static AmountVersionModel? openVersion(List<AmountVersionModel> history) {
    for (final version in history.reversed) {
      if (version.validTo == null) return version;
    }
    return null;
  }
}
