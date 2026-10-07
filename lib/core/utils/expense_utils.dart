import '../../data/models/expense_model.dart';
import '../../data/models/installment_model.dart';
import 'amount_version_utils.dart';

/// As contas sobre um gasto que a lista, o tile e o detalhe compartilham: quanto
/// ele cobra em um mês, qual foi o último valor, e que parcela cai naquele mês.
///
/// Moram aqui, e não no `ExpenseModel`, porque model não tem nada derivado — é a
/// regra em `.claude/rules/models.md`. Dos três destinos que a regra oferece,
/// este é o do meio: **a mesma regra serve a telas diferentes**. A lista soma o
/// valor do mês, e o tile e o detalhe mostram o valor e a parcela dele.
///
/// O que serve a um lugar só ficou no lugar que usa: o selo "Encerrado" é do
/// tile, e o "tem data de fim" que esconde as operações é do detalhe.
abstract final class ExpenseUtils {
  /// O valor cobrado em [month]. Null quando o gasto não é cobrado naquela
  /// competência.
  ///
  /// Procura nos dois lugares porque cada tipo guarda o dinheiro no seu: fixo
  /// na vigência, parcelado na parcela. Como nenhum gasto tem as duas listas
  /// preenchidas (GFX-09), não há ambiguidade — e quem chama não precisa saber
  /// de que tipo é o gasto.
  ///
  /// Existe porque o `amountCents` do gasto vem nulo quando a busca não leva
  /// `?month`, e a lista busca sem competência para não esconder o que já foi
  /// encerrado.
  static int? amountCentsIn(ExpenseModel expense, String month) =>
      AmountVersionUtils.amountCentsIn(expense.history, month) ??
      _installmentIn(expense, month)?.amountCents;

  /// O último valor que o gasto teve. É o que a lista mostra quando ele não é
  /// cobrado na competência exibida — encerrado, ou ainda por começar —, onde
  /// [amountCentsIn] não teria resposta.
  static int? latestAmountCents(ExpenseModel expense) {
    if (expense.history.isNotEmpty) return expense.history.last.amountCents;
    if (expense.installments.isNotEmpty) {
      return expense.installments.last.amountCents;
    }
    return expense.amountCents;
  }

  /// `'3/10'` para a parcela cobrada em [month], ou null em gasto fixo e nos
  /// meses sem parcela. O `installmentLabel` do backend só vem quando a busca
  /// leva `?month`, e a listagem da tela não leva.
  static String? installmentLabelIn(ExpenseModel expense, String month) {
    final installment = _installmentIn(expense, month);
    return installment == null ? null : installmentLabel(installment);
  }

  /// `'3/10'` — o mesmo texto que o backend devolve em `installmentLabel` para
  /// a competência consultada. Montado aqui porque a listagem sem `?month` não
  /// traz o campo, e a tela precisa dele mesmo assim.
  static String installmentLabel(InstallmentModel installment) =>
      '${installment.number}/${installment.total}';

  static InstallmentModel? _installmentIn(ExpenseModel expense, String month) {
    for (final installment in expense.installments) {
      if (installment.referenceMonth == month) return installment;
    }
    return null;
  }
}
