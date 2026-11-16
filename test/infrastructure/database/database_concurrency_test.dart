import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';
import 'package:smartflow/infrastructure/database/builtin_data.dart';

import '../../helper/database_write_lock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory directory;
  late AppDatabase writer;
  late AppDatabase reader;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'smartflow-database-concurrency-',
    );
    final file = File('${directory.path}/smartflow.sqlite.sqlite');
    writer = AppDatabase(NativeDatabase.createInBackground(file));
    await writer.customSelect('SELECT 1 AS value').getSingle();
    messenger.setMockMethodCallHandler(
      pathChannel,
      (call) async => call.method == 'getTemporaryDirectory'
          ? Directory.systemTemp.path
          : directory.path,
    );
    reader = AppDatabase();
  });

  tearDown(() async {
    await reader.close();
    await writer.close();
    messenger.setMockMethodCallHandler(pathChannel, null);
    await directory.delete(recursive: true);
  });

  test(
    'an up-to-date database opens while another connection writes',
    () async {
      await whileDatabaseWriteLocked(writer, () async {
        final result = await reader
            .customSelect('SELECT 1 AS value')
            .getSingle();
        expect(result.read<int>('value'), 1);
      });
    },
  );

  test('native write transactions wait for a short competing write', () async {
    await reader.customSelect('SELECT 1 AS value').getSingle();
    await whileDatabaseWriteLocked(
      writer,
      () => reader.transaction(() async {
        await reader
            .into(reader.appMetadata)
            .insertOnConflictUpdate(
              AppMetadataCompanion.insert(
                key: 'test.second_write',
                value: 'saved',
              ),
            );
      }),
      releaseAfter: const Duration(milliseconds: 300),
    );
    final row = await (writer.select(
      writer.appMetadata,
    )..where((row) => row.key.equals('test.second_write'))).getSingle();
    expect(row.value, 'saved');
  });

  test('startup builtin upgrades wait for a short competing write', () async {
    await (writer.update(writer.appMetadata)
          ..where((row) => row.key.equals(builtinDataVersionKey)))
        .write(const AppMetadataCompanion(value: Value('16')));
    await whileDatabaseWriteLocked(writer, () async {
      final row = await (reader.select(
        reader.appMetadata,
      )..where((row) => row.key.equals(builtinDataVersionKey))).getSingle();
      expect(row.value, currentBuiltinDataVersion.toString());
    }, releaseAfter: const Duration(milliseconds: 300));
  });
}
