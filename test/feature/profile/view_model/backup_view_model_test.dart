import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/data_management/backup/backup_archive.dart';
import 'package:smartflow/application/data_management/backup/backup_models.dart';
import 'package:smartflow/application/data_management/backup/backup_service.dart';
import 'package:smartflow/core/error/app_error_code.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/feature/profile/view_model/backup_view_model.dart';
import 'package:smartflow/feature/shared/view_model/ui_action_outcome.dart';

void main() {
  test('maps infrastructure failures to their stable UI error', () async {
    final container = ProviderContainer(
      overrides: [
        backupServiceProvider.overrideWithValue(_unusedService()),
        backupArchivePortProvider.overrideWithValue(
          _FailingBackupArchive(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(backupViewModelProvider.notifier);
    final outcome = await notifier.export();

    expect(outcome, isA<UiActionFailure<void>>());
    final failure = outcome as UiActionFailure<void>;
    expect(failure.error.code, 'infra.backup.write_failed');
    expect(failure.error.message, '无法保存备份，请检查文件权限后重试。');
    expect(container.read(backupViewModelProvider).busy, isFalse);
  });
}

BackupService _unusedService() {
  return BackupService(
    gateway: _UnusedGateway(),
    packageStore: _UnusedPackageStore(),
  );
}

class _FailingBackupArchive implements BackupArchivePort {
  @override
  Future<BackupManifest?> export(BackupService service) async {
    throw InfrastructureException(_BackupWriteFailed());
  }

  @override
  Future<BackupSelection?> pickForRestore() => throw UnimplementedError();

  @override
  Future<BackupDiff> compare(
    BackupService service,
    BackupSelection selection,
  ) => throw UnimplementedError();

  @override
  Future<BackupDiff> restore(
    BackupService service,
    BackupSelection selection,
  ) => throw UnimplementedError();
}

class _BackupWriteFailed implements AppErrorCode {
  @override
  String get code => 'infra.backup.write_failed';

  @override
  String get defaultMessage => '无法保存备份，请检查文件权限后重试。';
}

class _UnusedGateway implements BackupSnapshotGateway {
  @override
  int get schemaVersion => 1;

  @override
  Future<BackupSnapshot> readSnapshot() => throw UnimplementedError();

  @override
  Future<void> replaceSnapshot(BackupSnapshot snapshot) =>
      throw UnimplementedError();
}

class _UnusedPackageStore implements BackupPackageStore {
  @override
  Future<void> write(Object destination, BackupPackage package) =>
      throw UnimplementedError();

  @override
  Future<BackupPackage> read(Object source) => throw UnimplementedError();
}
