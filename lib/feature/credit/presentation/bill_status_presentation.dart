import '../../../application/credit/credit_query_api.dart';
import '../../../design_system/widget/app_status_badge.dart';

String billStatusLabel(BillStatus status) {
  return switch (status) {
    BillStatus.open => '累积中',
    BillStatus.billed => '已出账',
    BillStatus.settled => '已了结',
  };
}

AppStatusBadgePresentation billStatusBadgePresentation(BillStatus status) {
  return switch (status) {
    BillStatus.open => AppStatusBadgePresentation(
      label: billStatusLabel(status),
      tone: AppStatusTone.primary,
    ),
    BillStatus.billed => AppStatusBadgePresentation(
      label: billStatusLabel(status),
      tone: AppStatusTone.warning,
    ),
    BillStatus.settled => AppStatusBadgePresentation(
      label: billStatusLabel(status),
      tone: AppStatusTone.success,
    ),
  };
}
