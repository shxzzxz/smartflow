import 'package:smartflow/application/credit/credit_query_api.dart';
import 'package:smartflow/design_system/widget/app_status_badge.dart';

AppStatusBadgePresentation contractStatusBadgePresentation(
  InstallmentContractStatus status,
) {
  return switch (status) {
    InstallmentContractStatus.active => const AppStatusBadgePresentation(
      label: '进行中',
      tone: AppStatusTone.primary,
    ),
    InstallmentContractStatus.settled => const AppStatusBadgePresentation(
      label: '已结清',
      tone: AppStatusTone.success,
    ),
  };
}
