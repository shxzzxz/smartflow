import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import 'package:smartflow/application/data_management/icons/user_business_icon_models.dart';
import 'package:smartflow/core/id/id_generator.dart';
import 'package:smartflow/infrastructure/data_management/icons/platform_user_business_icon_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'stores a normalized PNG and removes it with its manifest entry',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'smartflow-user-icon-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final png = await _pngBytes();
      final store = PlatformUserBusinessIconStore(
        ids: _TestIds(),
        supportDirectory: () async => directory,
        pickImage: () async =>
            PickedUserBusinessIcon(name: '银行卡.png', bytes: png),
      );

      final icon = await store.pickAndStore(UserBusinessIconType.account);
      final loaded = await store.load();

      expect(icon, isNotNull);
      expect(icon!.label, '银行卡');
      expect(loaded.single.refId, icon.refId);
      final file = File(icon.filePath);
      expect(await file.exists(), isTrue);
      final bytes = await file.readAsBytes();
      expect(bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
      expect(_pngWidth(bytes), 256);
      expect(await store.exportBackupFiles(), hasLength(2));

      await store.delete(icon);

      expect(await file.exists(), isFalse);
      expect(await store.load(), isEmpty);
      expect(await store.exportBackupFiles(), isEmpty);
    },
  );
}

class _TestIds implements IdGenerator {
  var _next = 0;

  @override
  String newId() => 'icon-${++_next}';
}

Future<Uint8List> _pngBytes() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawColor(ui.Color(0xff3366ff), ui.BlendMode.src);
  final image = await recorder.endRecording().toImage(2, 2);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

int _pngWidth(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  return data.getUint32(16);
}
