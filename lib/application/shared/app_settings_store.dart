class AppSettings {
  const AppSettings({
    this.showAddTransactionFab = true,
    this.showBottomNavLabels = true,
  });

  final bool showAddTransactionFab;
  final bool showBottomNavLabels;

  AppSettings copyWith({
    bool? showAddTransactionFab,
    bool? showBottomNavLabels,
  }) {
    return AppSettings(
      showAddTransactionFab:
          showAddTransactionFab ?? this.showAddTransactionFab,
      showBottomNavLabels: showBottomNavLabels ?? this.showBottomNavLabels,
    );
  }
}

abstract interface class AppSettingsStore {
  Future<AppSettings> read();

  Future<void> save(AppSettings settings);
}
