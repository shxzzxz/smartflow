enum PullToCreateSensitivity {
  sensitive(storageValue: 'sensitive', triggerExtent: 56),
  standard(storageValue: 'standard', triggerExtent: 72),
  cautious(storageValue: 'cautious', triggerExtent: 96);

  const PullToCreateSensitivity({
    required this.storageValue,
    required this.triggerExtent,
  });

  final String storageValue;
  final double triggerExtent;

  static PullToCreateSensitivity? fromStorageValue(String? value) {
    return switch (value) {
      'sensitive' => PullToCreateSensitivity.sensitive,
      'standard' => PullToCreateSensitivity.standard,
      'cautious' => PullToCreateSensitivity.cautious,
      _ => null,
    };
  }
}

/// 日历热力维度。净收入按收入减支出取值，可正可负。
enum CalendarHeatMetric {
  expense(storageValue: 'expense'),
  income(storageValue: 'income'),
  net(storageValue: 'net');

  const CalendarHeatMetric({required this.storageValue});

  final String storageValue;

  static CalendarHeatMetric? fromStorageValue(String? value) {
    return switch (value) {
      'expense' => CalendarHeatMetric.expense,
      'income' => CalendarHeatMetric.income,
      'net' => CalendarHeatMetric.net,
      _ => null,
    };
  }
}

class AppSettings {
  const AppSettings({
    this.showAddTransactionFab = true,
    this.showBottomNavLabels = true,
    this.pullToCreateSensitivity = PullToCreateSensitivity.standard,
    this.copyPreviousMonthBudgetsOnOpen = false,
    this.calendarHeatmapEnabled = false,
    this.calendarHeatMetric = CalendarHeatMetric.expense,
  });

  final bool showAddTransactionFab;
  final bool showBottomNavLabels;
  final PullToCreateSensitivity pullToCreateSensitivity;
  final bool copyPreviousMonthBudgetsOnOpen;
  final bool calendarHeatmapEnabled;
  final CalendarHeatMetric calendarHeatMetric;

  AppSettings copyWith({
    bool? showAddTransactionFab,
    bool? showBottomNavLabels,
    PullToCreateSensitivity? pullToCreateSensitivity,
    bool? copyPreviousMonthBudgetsOnOpen,
    bool? calendarHeatmapEnabled,
    CalendarHeatMetric? calendarHeatMetric,
  }) {
    return AppSettings(
      showAddTransactionFab:
          showAddTransactionFab ?? this.showAddTransactionFab,
      showBottomNavLabels: showBottomNavLabels ?? this.showBottomNavLabels,
      pullToCreateSensitivity:
          pullToCreateSensitivity ?? this.pullToCreateSensitivity,
      copyPreviousMonthBudgetsOnOpen:
          copyPreviousMonthBudgetsOnOpen ?? this.copyPreviousMonthBudgetsOnOpen,
      calendarHeatmapEnabled:
          calendarHeatmapEnabled ?? this.calendarHeatmapEnabled,
      calendarHeatMetric: calendarHeatMetric ?? this.calendarHeatMetric,
    );
  }
}

abstract interface class AppSettingsStore {
  Future<AppSettings> read();

  Future<void> save(AppSettings settings);
}
