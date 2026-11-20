import '../../../application/shared/app_settings_store.dart';
import '../../../design_system/widget/app_choice_chip_group.dart';

const bottomNavigationStyleOptions =
    <AppChoiceChipOption<BottomNavigationStyle>>[
      AppChoiceChipOption(value: BottomNavigationStyle.classic, label: '经典'),
      AppChoiceChipOption(
        value: BottomNavigationStyle.frostedGlass,
        label: '玻璃',
      ),
    ];
