import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/update/app_update_channel.dart';
import 'package:smartflow/core/update/app_update_service.dart';

void main() {
  group('AppUpdateService', () {
    test('uses GitHub Pages as the default manifest host', () {
      final uri = AppUpdateService.manifestUriForChannel(AppUpdateChannel.beta);

      expect(
        uri.toString(),
        'https://shxzzxz.github.io/smartflow/update-beta.json',
      );
    });
  });
}
