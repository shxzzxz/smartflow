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

class AppSettings {
  const AppSettings({
    this.showAddTransactionFab = true,
    this.showBottomNavLabels = true,
    this.pullToCreateSensitivity = PullToCreateSensitivity.standard,
  });

  final bool showAddTransactionFab;
  final bool showBottomNavLabels;
  final PullToCreateSensitivity pullToCreateSensitivity;

  AppSettings copyWith({
    bool? showAddTransactionFab,
    bool? showBottomNavLabels,
    PullToCreateSensitivity? pullToCreateSensitivity,
  }) {
    return AppSettings(
      showAddTransactionFab:
          showAddTransactionFab ?? this.showAddTransactionFab,
      showBottomNavLabels: showBottomNavLabels ?? this.showBottomNavLabels,
      pullToCreateSensitivity:
          pullToCreateSensitivity ?? this.pullToCreateSensitivity,
    );
  }
}

abstract interface class AppSettingsStore {
  Future<AppSettings> read();

  Future<void> save(AppSettings settings);
}
