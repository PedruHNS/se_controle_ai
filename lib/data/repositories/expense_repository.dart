import 'package:multiple_result/multiple_result.dart';

import '../../core/errors/app_exception.dart';
import '../../core/errors/failure.dart';
import '../../core/errors/serialization_failure.dart';
import '../../core/network/api_client.dart';
import '../enums/expense_type.dart';
import '../enums/payment_method.dart';
import '../models/expense_model.dart';

abstract interface class ExpenseRepository {
  Future<Result<List<ExpenseModel>, Failure>> list({
    String? month,
    String? activeFrom,
    ExpenseType? type,
    PaymentMethod? paymentMethod,
    String? creditCardId,
  });

  Future<Result<ExpenseModel, Failure>> createFixed({
    required String description,
    required PaymentMethod paymentMethod,
    required int amountCents,
    required String startMonth,
    required String tagId,
    String? notes,
    String? creditCardId,
    bool recurring = true,
    String? spentAt,
  });

  Future<Result<ExpenseModel, Failure>> createInstallment({
    required String description,
    required PaymentMethod paymentMethod,
    required int totalCents,
    required int installmentsCount,
    required String firstMonth,
    required String tagId,
    String? notes,
    String? creditCardId,
    String? spentAt,
  });

  Future<Result<ExpenseModel, Failure>> updateDetails(
    String id, {
    required String description,
    required PaymentMethod paymentMethod,
    String? tagId,
    String? notes,
    String? creditCardId,
  });

  Future<Result<ExpenseModel, Failure>> adjust(
    String id, {
    required int amountCents,
    required String effectiveFrom,
  });

  Future<Result<ExpenseModel, Failure>> correct(
    String id, {
    required int amountCents,
  });

  Future<Result<ExpenseModel, Failure>> close(
    String id, {
    required String lastMonth,
  });

  Future<Result<ExpenseModel, Failure>> reschedule(
    String id, {
    required int newTotalCents,
    required int newInstallmentsCount,
    required String fromMonth,
  });

  Future<Result<ExpenseModel, Failure>> settle(
    String id, {
    required String fromMonth,
  });

  Future<Result<bool, Failure>> delete(String id);
}

class ExpenseRepositoryImpl implements ExpenseRepository {
  ExpenseRepositoryImpl(this._api);

  final ApiClient _api;

  @override
  Future<Result<List<ExpenseModel>, Failure>> list({
    String? month,
    String? activeFrom,
    ExpenseType? type,
    PaymentMethod? paymentMethod,
    String? creditCardId,
  }) async {
    try {
      final response = await _api.get(
        '/expenses',
        queryParameters: {
          'month': month,
          'activeFrom': activeFrom,
          'type': type?.wire,
          'paymentMethod': paymentMethod?.wire,
          'creditCardId': creditCardId,
        },
      );
      return Success(Decode.listOf(response.data, ExpenseModel.fromJson));
    } on AppException catch (exception) {
      return Error(Failure.fromException(exception));
    } catch (error, stackTrace) {
      return Error(serializationFailure(error, stackTrace));
    }
  }

  @override
  Future<Result<ExpenseModel, Failure>> createFixed({
    required String description,
    required PaymentMethod paymentMethod,
    required int amountCents,
    required String startMonth,
    required String tagId,
    String? notes,
    String? creditCardId,
    bool recurring = true,
    String? spentAt,
  }) async {
    try {
      final response = await _api.post(
        '/expenses',
        data: {
          'type': ExpenseType.fixed.wire,
          'description': description,
          'tagId': tagId,
          'notes': notes,
          'paymentMethod': paymentMethod.wire,
          'creditCardId': creditCardId,
          'amountCents': amountCents,
          'startMonth': startMonth,
          'recurring': recurring,
          'spentAt': ?spentAt,
        },
      );
      return Success(ExpenseModel.fromJson(Decode.object(response.data)));
    } on AppException catch (exception) {
      return Error(Failure.fromException(exception));
    } catch (error, stackTrace) {
      return Error(serializationFailure(error, stackTrace));
    }
  }

  @override
  Future<Result<ExpenseModel, Failure>> createInstallment({
    required String description,
    required PaymentMethod paymentMethod,
    required int totalCents,
    required int installmentsCount,
    required String firstMonth,
    required String tagId,
    String? notes,
    String? creditCardId,
    String? spentAt,
  }) async {
    try {
      final response = await _api.post(
        '/expenses',
        data: {
          'type': ExpenseType.installment.wire,
          'description': description,
          'tagId': tagId,
          'notes': notes,
          'paymentMethod': paymentMethod.wire,
          'creditCardId': creditCardId,
          'totalCents': totalCents,
          'installmentsCount': installmentsCount,
          'firstMonth': firstMonth,
          'spentAt': ?spentAt,
        },
      );
      return Success(ExpenseModel.fromJson(Decode.object(response.data)));
    } on AppException catch (exception) {
      return Error(Failure.fromException(exception));
    } catch (error, stackTrace) {
      return Error(serializationFailure(error, stackTrace));
    }
  }

  @override
  Future<Result<ExpenseModel, Failure>> updateDetails(
    String id, {
    required String description,
    required PaymentMethod paymentMethod,
    String? tagId,
    String? notes,
    String? creditCardId,
  }) async {
    try {
      final response = await _api.patch(
        '/expenses/$id',
        data: {
          'description': description,
          'paymentMethod': paymentMethod.wire,
          'tagId': ?tagId,
          'notes': notes,
          'creditCardId': creditCardId,
        },
      );
      return Success(ExpenseModel.fromJson(Decode.object(response.data)));
    } on AppException catch (exception) {
      return Error(Failure.fromException(exception));
    } catch (error, stackTrace) {
      return Error(serializationFailure(error, stackTrace));
    }
  }

  @override
  Future<Result<ExpenseModel, Failure>> adjust(
    String id, {
    required int amountCents,
    required String effectiveFrom,
  }) async {
    try {
      final response = await _api.post(
        '/expenses/$id/adjustments',
        data: {'amountCents': amountCents, 'effectiveFrom': effectiveFrom},
      );
      return Success(ExpenseModel.fromJson(Decode.object(response.data)));
    } on AppException catch (exception) {
      return Error(Failure.fromException(exception));
    } catch (error, stackTrace) {
      return Error(serializationFailure(error, stackTrace));
    }
  }

  @override
  Future<Result<ExpenseModel, Failure>> correct(
    String id, {
    required int amountCents,
  }) async {
    try {
      final response = await _api.patch(
        '/expenses/$id/amount',
        data: {'amountCents': amountCents},
      );
      return Success(ExpenseModel.fromJson(Decode.object(response.data)));
    } on AppException catch (exception) {
      return Error(Failure.fromException(exception));
    } catch (error, stackTrace) {
      return Error(serializationFailure(error, stackTrace));
    }
  }

  @override
  Future<Result<ExpenseModel, Failure>> close(
    String id, {
    required String lastMonth,
  }) async {
    try {
      final response = await _api.post(
        '/expenses/$id/closure',
        data: {'lastMonth': lastMonth},
      );
      return Success(ExpenseModel.fromJson(Decode.object(response.data)));
    } on AppException catch (exception) {
      return Error(Failure.fromException(exception));
    } catch (error, stackTrace) {
      return Error(serializationFailure(error, stackTrace));
    }
  }

  @override
  Future<Result<ExpenseModel, Failure>> reschedule(
    String id, {
    required int newTotalCents,
    required int newInstallmentsCount,
    required String fromMonth,
  }) async {
    try {
      final response = await _api.post(
        '/expenses/$id/reschedule',
        data: {
          'newTotalCents': newTotalCents,
          'newInstallmentsCount': newInstallmentsCount,
          'fromMonth': fromMonth,
        },
      );
      return Success(ExpenseModel.fromJson(Decode.object(response.data)));
    } on AppException catch (exception) {
      return Error(Failure.fromException(exception));
    } catch (error, stackTrace) {
      return Error(serializationFailure(error, stackTrace));
    }
  }

  @override
  Future<Result<ExpenseModel, Failure>> settle(
    String id, {
    required String fromMonth,
  }) async {
    try {
      final response = await _api.post(
        '/expenses/$id/settlement',
        data: {'fromMonth': fromMonth},
      );
      return Success(ExpenseModel.fromJson(Decode.object(response.data)));
    } on AppException catch (exception) {
      return Error(Failure.fromException(exception));
    } catch (error, stackTrace) {
      return Error(serializationFailure(error, stackTrace));
    }
  }

  @override
  Future<Result<bool, Failure>> delete(String id) async {
    try {
      await _api.delete('/expenses/$id');
      return Success(true);
    } on AppException catch (exception) {
      return Error(Failure.fromException(exception));
    } catch (error, stackTrace) {
      return Error(serializationFailure(error, stackTrace));
    }
  }
}
