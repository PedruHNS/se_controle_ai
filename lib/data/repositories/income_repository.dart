import 'package:multiple_result/multiple_result.dart';

import '../../core/errors/app_exception.dart';
import '../../core/errors/failure.dart';
import '../../core/errors/serialization_failure.dart';
import '../../core/network/api_client.dart';
import '../models/income_model.dart';

abstract interface class IncomeRepository {
  Future<Result<List<IncomeModel>, Failure>> list({required String month});
  Future<Result<IncomeModel, Failure>> getById(String id, {String? month});
  Future<Result<String, Failure>> create({
    required String description,
    required int amountCents,
    required String startMonth,
    bool recurring = true,
  });
  Future<Result<bool, Failure>> adjust(
    String id, {
    required int amountCents,
    required String effectiveFrom,
  });
  Future<Result<bool, Failure>> correct(String id, {required int amountCents});
  Future<Result<bool, Failure>> close(String id, {required String lastMonth});
  Future<Result<bool, Failure>> delete(String id);
}

class IncomeRepositoryImpl implements IncomeRepository {
  final ApiClient _api;
  IncomeRepositoryImpl(this._api);

  @override
  Future<Result<List<IncomeModel>, Failure>> list({
    required String month,
  }) async {
    try {
      final response = await _api.get(
        '/incomes',
        queryParameters: {'month': month},
      );
      return Success(Decode.listOf(response.data, IncomeModel.fromJson));
    } on AppException catch (exception) {
      return Error(Failure.fromException(exception));
    } catch (error, stackTrace) {
      return Error(serializationFailure(error, stackTrace));
    }
  }

  @override
  Future<Result<IncomeModel, Failure>> getById(
    String id, {
    String? month,
  }) async {
    try {
      final response = await _api.get(
        '/incomes/$id',
        queryParameters: {'month': month},
      );
      return Success(IncomeModel.fromJson(Decode.object(response.data)));
    } on AppException catch (exception) {
      return Error(Failure.fromException(exception));
    } catch (error, stackTrace) {
      return Error(serializationFailure(error, stackTrace));
    }
  }

  @override
  Future<Result<String, Failure>> create({
    required String description,
    required int amountCents,
    required String startMonth,
    bool recurring = false,
  }) async {
    try {
      final response = await _api.post(
        '/incomes',
        data: {
          'description': description,
          'amountCents': amountCents,
          'startMonth': startMonth,
          'recurring': recurring,
        },
      );
      return Success(Decode.object(response.data)['id'] as String);
    } on AppException catch (exception) {
      return Error(Failure.fromException(exception));
    } catch (error, stackTrace) {
      return Error(serializationFailure(error, stackTrace));
    }
  }

  @override
  Future<Result<bool, Failure>> adjust(
    String id, {
    required int amountCents,
    required String effectiveFrom,
  }) async {
    try {
      await _api.post(
        '/incomes/$id/adjustments',
        data: {'amountCents': amountCents, 'effectiveFrom': effectiveFrom},
      );
      return Success(true);
    } on AppException catch (exception) {
      return Error(Failure.fromException(exception));
    } catch (error, stackTrace) {
      return Error(serializationFailure(error, stackTrace));
    }
  }

  @override
  Future<Result<bool, Failure>> correct(
    String id, {
    required int amountCents,
  }) async {
    try {
      await _api.patch(
        '/incomes/$id/amount',
        data: {'amountCents': amountCents},
      );
      return Success(true);
    } on AppException catch (exception) {
      return Error(Failure.fromException(exception));
    } catch (error, stackTrace) {
      return Error(serializationFailure(error, stackTrace));
    }
  }

  @override
  Future<Result<bool, Failure>> close(
    String id, {
    required String lastMonth,
  }) async {
    try {
      await _api.post('/incomes/$id/closure', data: {'lastMonth': lastMonth});
      return Success(true);
    } on AppException catch (exception) {
      return Error(Failure.fromException(exception));
    } catch (error, stackTrace) {
      return Error(serializationFailure(error, stackTrace));
    }
  }

  @override
  Future<Result<bool, Failure>> delete(String id) async {
    try {
      await _api.delete('/incomes/$id');
      return Success(true);
    } on AppException catch (exception) {
      return Error(Failure.fromException(exception));
    } catch (error, stackTrace) {
      return Error(serializationFailure(error, stackTrace));
    }
  }
}
