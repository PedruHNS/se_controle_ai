import 'package:multiple_result/multiple_result.dart';

import '../../core/errors/app_exception.dart';
import '../../core/errors/failure.dart';
import '../../core/network/api_client.dart';
import '../models/month_projection_model.dart';
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

  /// A seção de débito.
  Future<Result<SummarySectionModel, Failure>> getDebit({String? month});

  /// Uma fatura por cartão, com total da competência e as linhas dela.
  Future<Result<List<CreditCardInvoiceModel>, Failure>> getCreditCards({
    String? month,
  });

  /// Resumo do mês inteiro numa resposta. A home não usa mais — ver
  /// [MonthlySummaryModel].
  Future<Result<MonthlySummaryModel, Failure>> getMonthly({String? month});

  /// Projeção de saldo a partir de [from], por [months] meses (1 a 60).
  Future<Result<List<MonthProjectionModel>, Failure>> getProjection({
    String? from,
    int months = 12,
  });
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

  /// As quatro rotas da home só diferem no caminho e no decode. Repetir o
  /// `try/catch` quatro vezes seria quatro lugares para esquecer o
  /// [_serializationFailure] — o que transforma campo com tipo trocado em
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
      return Error(_serializationFailure(error, stackTrace));
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
      return Error(_serializationFailure(error, stackTrace));
    }
  }

  @override
  Future<Result<List<MonthProjectionModel>, Failure>> getProjection({
    String? from,
    int months = 12,
  }) async {
    try {
      final response = await _api.get(
        '/summary/projection',
        queryParameters: {'from': from, 'months': months},
      );
      return Success(
        Decode.listOf(response.data, MonthProjectionModel.fromJson),
      );
    } on AppException catch (exception) {
      return Error(Failure.fromException(exception));
    } catch (error, stackTrace) {
      return Error(_serializationFailure(error, stackTrace));
    }
  }

  /// O decode fica dentro do `try` de propósito: `on AppException` não pega o
  /// `TypeError` de um cast, então um campo que mudou de tipo no backend viraria
  /// crash em vez de erro tratado. Este `catch` é a rede para isso.
  Failure _serializationFailure(Object error, StackTrace stackTrace) =>
      Failure.fromException(
        SerializationException(
          message: '$error',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
}
