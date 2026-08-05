import '../../../application/shared/app_settings_store.dart';
import '../../../design_system/widget/app_select.dart';

const pullToCreateSensitivityOptions =
    <AppSelectOption<PullToCreateSensitivity>>[
      AppSelectOption(value: PullToCreateSensitivity.sensitive, label: '灵敏'),
      AppSelectOption(value: PullToCreateSensitivity.standard, label: '标准'),
      AppSelectOption(value: PullToCreateSensitivity.cautious, label: '稳妥'),
    ];
