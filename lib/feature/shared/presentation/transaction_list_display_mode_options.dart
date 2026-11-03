import '../../../application/shared/app_settings_store.dart';
import '../../../design_system/widget/app_select.dart';

const transactionListDisplayModeOptions =
    <AppSelectOption<TransactionListDisplayMode>>[
      AppSelectOption(value: TransactionListDisplayMode.standard, label: '标准'),
      AppSelectOption(value: TransactionListDisplayMode.compact, label: '紧凑'),
    ];
