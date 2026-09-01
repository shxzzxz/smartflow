import 'backup_models.dart';
import 'backup_service.dart';

/// Platform-neutral archive workflow used by the profile ViewModel.
abstract interface class BackupArchivePort {
  Future<BackupManifest?> export(BackupService service);

  Future<BackupSelection?> pickForRestore();

  Future<BackupDiff> compare(BackupService service, BackupSelection selection);

  Future<BackupDiff> restore(BackupService service, BackupSelection selection);
}

class BackupSelection {
  const BackupSelection({required this.source, required this.dispose});

  final Object source;
  final Future<void> Function() dispose;
}
