import 'package:multiple_result/multiple_result.dart';

import '../../core/errors/app_exception.dart';
import '../../core/errors/failure.dart';
import '../../core/network/api_client.dart';
import '../models/credit_card_bill_model.dart';
import '../models/credit_card_model.dart';

abstract interface class CreditCardRepository {
  Future<Result<List<CreditCardModel>, Failure>> list({String? month});
  Future<Result<CreditCardModel, Failure>> getById(String id, {String? month});
  Future<Result<CreditCardBillModel, Failure>> getBill(
    String id, {
    required String month,
  });
  Future<Result<CreditCardModel, Failure>> create({
    required String name,
    required int closingDay,
    required int dueDay,
    String? lastDigits,
    int? limitCents,
  });
  Future<Result<CreditCardModel, Failure>> update(
    String id, {
    required String name,
    required int closingDay,
    required int dueDay,
    String? lastDigits,
    int? limitCents,
    String? month,
  });
  Future<Result<bool, Failure>> delete(String id);
}

class CreditCardRepositoryImpl implements CreditCardRepository {
  CreditCardRepositoryImpl(this._api);

  final ApiClient _api;

  @override
  Future<Result<List<CreditCardModel>, Failure>> list({String? month}) async {
    try {
      final response = await _api.get(
        '/credit-cards',
        queryParameters: {'month': month},
      );
      return Success(Decode.listOf(response.data, CreditCardModel.fromJson));
    } on AppException catch (exception) {
      return Error(Failure.fromException(exception));
    } catch (error, stackTrace) {
      return Error(_serializationFailure(error, stackTrace));
    }
  }

  @override
  Future<Result<CreditCardModel, Failure>> getById(
    String id, {
    String? month,
  }) async {
    try {
      final response = await _api.get(
        '/credit-cards/$id',
        queryParameters: {'month': month},
      );
      return Success(CreditCardModel.fromJson(Decode.object(response.data)));
    } on AppException catch (exception) {
      return Error(Failure.fromException(exception));
    } catch (error, stackTrace) {
      return Error(_serializationFailure(error, stackTrace));
    }
  }

  @override
  Future<Result<CreditCardBillModel, Failure>> getBill(
    String id, {
    required String month,
  }) async {
    try {
      final response = await _api.get(
        '/credit-cards/$id/invoice',
        queryParameters: {'month': month},
      );
      return Success(
        CreditCardBillModel.fromJson(Decode.object(response.data)),
      );
    } on AppException catch (exception) {
      return Error(Failure.fromException(exception));
    } catch (error, stackTrace) {
      return Error(_serializationFailure(error, stackTrace));
    }
  }

  @override
  Future<Result<CreditCardModel, Failure>> create({
    required String name,
    required int closingDay,
    required int dueDay,
    String? lastDigits,
    int? limitCents,
  }) async {
    try {
      final response = await _api.post(
        '/credit-cards',
        data: {
          'name': name,
          'closingDay': closingDay,
          'dueDay': dueDay,
          'lastDigits': ?lastDigits,
          'limitCents': ?limitCents,
        },
      );
      return Success(CreditCardModel.fromJson(Decode.object(response.data)));
    } on AppException catch (exception) {
      return Error(Failure.fromException(exception));
    } catch (error, stackTrace) {
      return Error(_serializationFailure(error, stackTrace));
    }
  }

  @override
  Future<Result<CreditCardModel, Failure>> update(
    String id, {
    required String name,
    required int closingDay,
    required int dueDay,
    String? lastDigits,
    int? limitCents,
    String? month,
  }) async {
    try {
      final response = await _api.post(
        '/credit-cards/$id',
        queryParameters: {'month': month},
        data: {
          'name': name,
          'closingDay': closingDay,
          'dueDay': dueDay,
          'lastDigits': lastDigits,
          'limitCents': limitCents,
        },
      );
      return Success(CreditCardModel.fromJson(Decode.object(response.data)));
    } on AppException catch (exception) {
      return Error(Failure.fromException(exception));
    } catch (error, stackTrace) {
      return Error(_serializationFailure(error, stackTrace));
    }
  }

  @override
  Future<Result<bool, Failure>> delete(String id) async {
    try {
      await _api.delete('/credit-cards/$id');
      return Success(true);
    } on AppException catch (exception) {
      return Error(Failure.fromException(exception));
    } catch (error, stackTrace) {
      return Error(_serializationFailure(error, stackTrace));
    }
  }

  Failure _serializationFailure(Object error, StackTrace stackTrace) =>
      Failure.fromException(
        SerializationException(
          message: '$error',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
}
