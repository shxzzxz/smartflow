import 'package:drift/drift.dart';

import '../../../domain/credit/valobj/reference_rate.dart';
import '../../credit/mapper/installment_stage_mapper.dart';
import '../app_database.dart';

/// 将自动生成进度从结果生效日换算为重定价日，保留已删除结果的进度。
Future<void> migrateRepricingResetProgress(
  AppDatabase database,
) => database.transaction(() async {
  final configurations = await database
      .select(database.installmentRepricingConfigs)
      .get();
  for (final row in configurations) {
    if (row.lastGeneratedDate == null) continue;
    final configuration = decodeRepricingConfiguration(row);
    configuration.rule.validate();
    final index = configuration.rule.effectiveCycleOnOrBefore(
      row.lastGeneratedDate!,
    );
    final reset = index == null ? null : configuration.rule.resetDate(index);
    final progress =
        reset == null ||
            reset.isBefore(referenceDate(configuration.effectiveFrom))
        ? null
        : reset;
    await (database.update(
      database.installmentRepricingConfigs,
    )..where((value) => value.id.equals(row.id))).write(
      InstallmentRepricingConfigsCompanion(lastGeneratedDate: Value(progress)),
    );
  }
});
