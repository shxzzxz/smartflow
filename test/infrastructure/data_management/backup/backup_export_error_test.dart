import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/data_management/backup/backup_models.dart';
import 'package:smartflow/application/data_management/backup/backup_service.dart';
import 'package:smartflow/feature/profile/view_model/backup_view_model.dart';
import 'package:smartflow/feature/shared/view_model/ui_action_outcome.dart';
import 'package:smartflow/infrastructure/data_management/backup/file_backup_package_store.dart';
import 'package:smartflow/infrastructure/data_management/backup/platform_backup_archive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory temporaryDirectory;
  late _Gateway gateway;
  late _Picker picker;
  late ProviderContainer container;
  late List<LogRecord> records;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'backup-errors-',
    );
    messenger.setMockMethodCallHandler(
      pathChannel,
      (call) async => temporaryDirectory.path,
    );
    final originalPicker = FilePickerPlatform.instance;
    picker = _Picker();
    FilePickerPlatform.instance = picker;
    gateway = _Gateway();
    records = [];
    final previousLevel = Logger.root.level;
    Logger.root.level = Level.ALL;
    final subscription = Logger.root.onRecord.listen((record) {
      if (record.loggerName.contains('backup')) records.add(record);
    });
    container = ProviderContainer(
      overrides: [
        backupServiceProvider.overrideWithValue(
          BackupService(
            gateway: gateway,
            packageStore: const FileBackupPackageStore(),
          ),
        ),
        backupArchivePortProvider.overrideWithValue(
          const PlatformBackupArchive(),
        ),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await subscription.cancel();
      Logger.root.level = previousLevel;
      FilePickerPlatform.instance = originalPicker;
      messenger.setMockMethodCallHandler(pathChannel, null);
      await temporaryDirectory.delete(recursive: true);
    });
  });

  Future<UiActionOutcome<void>> export() =>
      container.read(backupViewModelProvider.notifier).export();

  List<LogRecord> failures() =>
      records.where((r) => r.level >= Level.WARNING).toList();

  test(
    'snapshot validation before picker keeps its category and diagnostic log',
    () async {
      gateway.snapshot = BackupSnapshot(
        tables: {
          'tags': [
            {'id': 'duplicate'},
            {'id': 'duplicate'},
          ],
        },
      );
      final result = await export() as UiActionFailure<void>;
      expect(result.error.code, 'backup.invalid');
      expect(result.error.message, isNot(contains('duplicate')));
      expect(picker.calls, 0);
      expect(failures(), hasLength(1));
      expect(failures().single.error, isA<BackupValidationException>());
      expect(failures().single.message, contains('backup.invalid'));
      expect(failures().single.stackTrace, isNotNull);
      expect(container.read(backupViewModelProvider).busy, isFalse);
    },
  );

  test(
    'unknown snapshot failure is logged unchanged and shown as unknown',
    () async {
      final cause = Exception('database detail');
      gateway.failure = cause;
      final result = await export() as UiActionFailure<void>;
      expect(result.error.code, 'unknown');
      expect(result.error.message, isNot(contains('database detail')));
      expect(picker.calls, 0);
      expect(failures(), hasLength(1));
      expect(failures().single.level, Level.SEVERE);
      expect(failures().single.error, same(cause));
      expect(
        failures().single.stackTrace.toString(),
        contains('_Gateway.readSnapshot'),
      );
    },
  );

  test(
    'temporary directory failure has preparation category and original cause',
    () async {
      messenger.setMockMethodCallHandler(pathChannel, (call) async => null);
      final result = await export() as UiActionFailure<void>;
      expect(result.error.code, 'infra.backup.prepare_failed');
      expect(picker.calls, 0);
      expect(failures(), hasLength(1));
      expect(
        failures().single.error.toString(),
        contains('MissingPlatformDirectoryException'),
      );
      expect(failures().single.stackTrace, isNotNull);
    },
  );

  test(
    'staging write failure is preparation failure before opening picker',
    () async {
      final blocker = await File(
        '${temporaryDirectory.path}/not-a-directory',
      ).writeAsString('');
      messenger.setMockMethodCallHandler(
        pathChannel,
        (call) async => blocker.path,
      );
      final result = await export() as UiActionFailure<void>;
      expect(result.error.code, 'infra.backup.prepare_failed');
      expect(picker.calls, 0);
      expect(failures(), hasLength(1));
      expect(failures().single.error, isA<FileSystemException>());
    },
  );

  test('format details are logged but are not exposed to the user', () async {
    const cause = FormatException('internal field and data');
    gateway.failure = cause;
    final result = await export() as UiActionFailure<void>;
    expect(result.error.code, 'backup.invalid');
    expect(result.error.message, isNot(contains(cause.message)));
    expect(failures(), hasLength(1));
    expect(failures().single.error, same(cause));
    expect(failures().single.stackTrace, isNotNull);
  });

  test(
    'save failure keeps platform details in one log and cleans staging',
    () async {
      final cause = PlatformException(
        code: 'save_failed',
        message: 'provider detail',
      );
      picker.failure = cause;
      final result = await export() as UiActionFailure<void>;
      expect(result.error.code, 'infra.backup.write_failed');
      expect(result.error.message, isNot(contains('权限')));
      expect(result.error.message, isNot(contains('provider detail')));
      expect(failures(), hasLength(1));
      expect(failures().single.error, same(cause));
      expect(
        failures().single.stackTrace.toString(),
        contains('_Picker.saveFile'),
      );
      expect(failures().single.message, contains('infra.backup.write_failed'));
      expect(await temporaryDirectory.list().toList(), isEmpty);
    },
  );

  test(
    'cancel is successful without error logging and cleans staging',
    () async {
      expect(await export(), isA<UiActionSuccess<void>>());
      expect(picker.calls, 1);
      expect(picker.bytes, isNotEmpty);
      expect(failures(), isEmpty);
      expect(await temporaryDirectory.list().toList(), isEmpty);
      expect(container.read(backupViewModelProvider).busy, isFalse);
    },
  );

  test('programming errors propagate to the global boundary', () async {
    final cause = StateError('programming error');
    gateway.failure = cause;
    await expectLater(export(), throwsA(same(cause)));
    expect(failures(), isEmpty);
    expect(container.read(backupViewModelProvider).busy, isFalse);
  });
}

class _Gateway implements BackupSnapshotGateway {
  Object? failure;
  BackupSnapshot snapshot = BackupSnapshot();
  @override
  int get schemaVersion => 1;
  @override
  Future<BackupSnapshot> readSnapshot() async {
    if (failure != null) throw failure!;
    return snapshot;
  }

  @override
  Future<void> replaceSnapshot(BackupSnapshot snapshot) =>
      throw UnimplementedError();
}

class _Picker extends FilePickerPlatform {
  Object? failure;
  int calls = 0;
  Uint8List? bytes;
  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? dialogTitle,
    String? initialDirectory,
    Function(FilePickerStatus)? onFileSaving,
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    calls++;
    this.bytes = bytes;
    if (failure != null) throw failure!;
    return null;
  }
}
