class AppVersionInfo {
  const AppVersionInfo({required this.versionName, required this.buildNumber});

  final String versionName;

  /// Base build number shared by all platform packages from this release.
  final int buildNumber;

  String get displayName => '$versionName+$buildNumber';
}
