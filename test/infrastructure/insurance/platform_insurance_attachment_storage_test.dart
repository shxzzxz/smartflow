import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/infrastructure/insurance/platform_insurance_attachment_storage.dart';

import '../../helper/sequential_id_generator.dart';

void main() {
  late Directory supportDirectory;

  setUp(() async {
    supportDirectory = await Directory.systemTemp.createTemp(
      'smartflow-insurance-attachments-',
    );
  });

  tearDown(() async {
    if (await supportDirectory.exists()) {
      await supportDirectory.delete(recursive: true);
    }
  });

  test('rejects storage keys outside the insurance attachment root', () async {
    final outsideFile = File(
      path.join(supportDirectory.path, 'logs', 'smartflow.log'),
    );
    await outsideFile.parent.create(recursive: true);
    await outsideFile.writeAsString('keep');
    final storage = _storage(supportDirectory);

    await expectLater(
      storage.delete(path.join('logs', 'smartflow.log')),
      throwsA(
        isA<InfrastructureException>().having(
          (error) => error.code,
          'code',
          'infra.insurance_attachment.invalid_storage_key',
        ),
      ),
    );

    expect(await outsideFile.readAsString(), 'keep');
  });

  test('removes earlier copies when a later selected file fails', () async {
    final sourceDirectory = Directory(
      path.join(supportDirectory.path, 'source'),
    );
    await sourceDirectory.create();
    final source = File(path.join(sourceDirectory.path, 'first.pdf'));
    await source.writeAsString('contract');
    final storage = _storage(
      supportDirectory,
      pickFiles: () async => [
        _TestPlatformFile('first.pdf', source.uri),
        _TestPlatformFile(
          'missing.pdf',
          File(path.join(sourceDirectory.path, 'missing.pdf')).uri,
        ),
      ],
    );

    await expectLater(
      storage.pickAndStore(commercialInsuranceId: 'insurance-1'),
      throwsA(
        isA<InfrastructureException>().having(
          (error) => error.code,
          'code',
          'infra.insurance_attachment.copy_failed',
        ),
      ),
    );

    final targetDirectory = Directory(
      path.join(supportDirectory.path, 'insurance_attachments', 'insurance-1'),
    );
    expect(
      await targetDirectory.exists()
          ? await targetDirectory.list().toList()
          : const <FileSystemEntity>[],
      isEmpty,
    );
  });
}

PlatformInsuranceAttachmentStorage _storage(
  Directory supportDirectory, {
  Future<List<PlatformFile>> Function()? pickFiles,
}) {
  return PlatformInsuranceAttachmentStorage(
    ids: SequentialIdGenerator(prefix: 'file'),
    pickFiles: pickFiles,
    supportDirectory: () async => supportDirectory,
  );
}

final class _TestPlatformFile extends PlatformFile {
  _TestPlatformFile(this.name, this.uri);

  @override
  final String name;

  @override
  final Uri uri;

  @override
  Never get xFile => throw UnimplementedError();

  @override
  Future<int> length() => File(this.path!).length();

  @override
  Future<Uint8List> readAsBytes() => File(this.path!).readAsBytes();

  @override
  Stream<Uint8List> readAsByteStream() =>
      File(this.path!).openRead().map(Uint8List.fromList);
}
