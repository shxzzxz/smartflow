import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// 用真实文件内容模拟 `flutter/assets` 通道。
///
/// 避免同一 isolate 内跨用例重复加载同一资源时，
/// `rootBundle` 在测试环境中的缓存 Future 偶发无法完成导致的挂起。
void mockManualAssets() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', (ByteData? message) async {
        if (message == null) {
          return null;
        }
        final key = utf8.decode(message.buffer.asUint8List());
        if (!key.startsWith('assets/manual/')) {
          return null;
        }
        final file = File(key);
        if (!file.existsSync()) {
          return null;
        }
        return ByteData.sublistView(file.readAsBytesSync());
      });
}

void clearManualAssetsMock() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', null);
}
