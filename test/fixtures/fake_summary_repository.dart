import 'package:multiple_result/multiple_result.dart';
import 'package:se_controle_ai/core/errors/failure.dart';
import 'package:se_controle_ai/data/models/month_projection_model.dart';
import 'package:se_controle_ai/data/models/monthly_summary_model.dart';
import 'package:se_controle_ai/data/repositories/summary_repository.dart';

import 'summary_fixture.dart';

/// Repositório falso: é para isto que a interface do repositório existe. Zero
/// Dio, zero servidor, teste em milissegundos.
class FakeSummaryRepository implements SummaryRepository {
  FakeSummaryRepository();

  /// Resposta a devolver. Trocar entre chamadas simula erro depois de sucesso.
  Result<MonthlySummaryModel, Failure> response = Success(
    MonthlySummaryModel.fromJson(summaryJson),
  );

  /// Meses pedidos, na ordem — para verificar o que o controller consultou.
  final List<String?> requestedMonths = [];

  /// Quando definido, atrasa a resposta. Serve para testar corrida.
  Duration? delay;

  @override
  Future<Result<MonthlySummaryModel, Failure>> getMonthly({
    String? month,
  }) async {
    requestedMonths.add(month);
    if (delay != null) await Future<void>.delayed(delay!);
    return response;
  }

  @override
  Future<Result<List<MonthProjectionModel>, Failure>> getProjection({
    String? from,
    int months = 12,
  }) async => const Success([]);
}
