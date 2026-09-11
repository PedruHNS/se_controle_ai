import 'package:multiple_result/multiple_result.dart';

import '../../core/errors/app_exception.dart';
import '../../core/errors/failure.dart';
import '../../core/errors/serialization_failure.dart';
import '../../core/network/api_client.dart';
import '../models/credit_card_invoice_model.dart';
import '../models/monthly_balance_model.dart';
import '../models/monthly_summary_model.dart';
import '../models/summary_section_model.dart';

/// Interface e não classe concreta direto: é o que permite o teste do controller
/// injetar um repositório falso sem subir Dio nem servidor.
abstract interface class SummaryRepository {
  /// Sem [month], o backend usa a competência corrente — vale para todos.

  /// Os números do topo da home: ganho, gasto, saldo e % comprometida.
  Future<Result<MonthlyBalanceModel, Failure>> getBalance({String? month});

  /// A seção Ganhos.
  Future<Result<SummarySectionModel, Failure>> getIncomes({String? month});

  /// A seção de gastos: tudo que sai no mês, débito e cartão juntos.
  Future<Result<SummarySectionModel, Failure>> getExpenses({String? month});

  /// A seção de débito — só o que **não** vai na fatura.
  Future<Result<SummarySectionModel, Failure>> getDebit({String? month});

  /// Uma fatura por cartão, com total da competência e as linhas dela.
  Future<Result<List<CreditCardInvoiceModel>, Failure>> getCreditCards({
    String? month,
  });

  /// Resumo do mês inteiro numa resposta. A home não usa mais — ver
  /// [MonthlySummaryModel].
  Future<Result<MonthlySummaryModel, Failure>> getMonthly({String? month});
}

class SummaryRepositoryImpl implements SummaryRepository {
  SummaryRepositoryImpl(this._api);

  final ApiClient _api;

  @override
  Future<Result<MonthlyBalanceModel, Failure>> getBalance({String? month}) =>
      _read(
        '/summary/balance',
        month,
        (data) => MonthlyBalanceModel.fromJson(Decode.object(data)),
      );

  @override
  Future<Result<SummarySectionModel, Failure>> getIncomes({String? month}) =>
      _read(
        '/summary/incomes',
        month,
        (data) => SummarySectionModel.fromJson(Decode.object(data)),
      );

  @override
  Future<Result<SummarySectionModel, Failure>> getExpenses({String? month}) =>
      _read(
        '/summary/expenses',
        month,
        (data) => SummarySectionModel.fromJson(Decode.object(data)),
      );

  @override
  Future<Result<SummarySectionModel, Failure>> getDebit({String? month}) =>
      _read(
        '/summary/debit',
        month,
        (data) => SummarySectionModel.fromJson(Decode.object(data)),
      );

  @override
  Future<Result<List<CreditCardInvoiceModel>, Failure>> getCreditCards({
    String? month,
  }) => _read(
    '/summary/credit-cards',
    month,
    (data) => Decode.listOf(data, CreditCardInvoiceModel.fromJson),
  );

  /// As rotas de seção da home só diferem no caminho e no decode. Repetir o
  /// `try/catch` em cada uma seria um lugar por seção para esquecer o
  /// [serializationFailure] — o que transforma campo com tipo trocado em
  /// crash, em vez de erro tratado.
  Future<Result<T, Failure>> _read<T>(
    String path,
    String? month,
    T Function(dynamic data) decode,
  ) async {
    try {
      final response = await _api.get(path, queryParameters: {'month': month});
      return Success(decode(response.data));
    } on AppException catch (exception) {
      return Error(Failure.fromException(exception));
    } catch (error, stackTrace) {
      return Error(serializationFailure(error, stackTrace));
    }
  }

  @override
  Future<Result<MonthlySummaryModel, Failure>> getMonthly({
    String? month,
  }) async {
    try {
      final response = await _api.get(
        '/summary',
        queryParameters: {'month': month},
      );
      return Success(
        MonthlySummaryModel.fromJson(Decode.object(response.data)),
      );
    } on AppException catch (exception) {
      return Error(Failure.fromException(exception));
    } catch (error, stackTrace) {
      return Error(serializationFailure(error, stackTrace));
    }
  }
}
