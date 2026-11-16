import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';
import 'package:smartflow/infrastructure/database/builtin_data.dart';

import '../../helper/database_write_lock.dart';

class _VmServiceHttpOverrides extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory directory;
  late AppDatabase writer;
  late AppDatabase reader;

  setUpAll(() async {
    final info = await developer.Service.controlWebServer(
      enable: true,
      silenceOutput: true,
    ).timeout(const Duration(seconds: 5));
    final uri = info.serverUri;
    if (uri == null) throw StateError('VM service is unavailable.');
    final client = HttpOverrides.runWithHttpOverrides(
      () => HttpClient(),
      _VmServiceHttpOverrides(),
    );
    try {
      final request = await client.getUrl(
        uri
            .resolve('setFlag')
            .replace(queryParameters: {'name': 'profiler', 'value': 'false'}),
      );
      final response = await request.close();
      final json =
          jsonDecode(await response.transform(utf8.decoder).join())
              as Map<String, dynamic>;
      final result = (json['result'] ?? json) as Map<String, dynamic>;
      // ignore: avoid_print
      print('[DEBUG-v098-lock] profiler disabled: $result');
      if (result['type'] != 'Success') {
        throw StateError('Failed to disable VM profiler: $result');
      }
    } finally {
      client.close(force: true);
    }
  });

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
    final timeout = await reader
        .customSelect('PRAGMA busy_timeout')
        .getSingle();
    final journal = await reader
        .customSelect('PRAGMA journal_mode')
        .getSingle();
    final sqlite = await reader
        .customSelect('SELECT sqlite_version() AS version')
        .getSingle();
    // ignore: avoid_print
    print(
      '[DEBUG-v098-lock] timeout=${timeout.data} journal=${journal.data} sqlite=${sqlite.data}',
    );
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
