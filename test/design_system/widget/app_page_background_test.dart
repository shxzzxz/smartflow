import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/shared/app_settings_store.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/design_system/widget/app_scaffold.dart';

void main() {
  testWidgets(
    'gradient stays opaque, tints the lower corner and can be disabled',
    (tester) async {
      const key = ValueKey('background-capture');
      Future<ui.Image> render(
        double depth, {
        AppBackgroundStyle style = AppBackgroundStyle.multiGlow,
      }) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(
              appearance: AppAppearanceSettings(
                gradientDepth: depth,
                backgroundStyle: style,
              ),
            ),
            home: Center(
              child: RepaintBoundary(
                key: key,
                child: const SizedBox(
                  width: 100,
                  height: 200,
                  child: AppScaffold(body: SizedBox.expand()),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(key),
        );
        return tester
            .runAsync(() => boundary.toImage(pixelRatio: 1))
            .then((image) => image!);
      }

      Future<List<int>> pixel(ui.Image image, int x, int y) async {
        final data = await tester.runAsync(
          () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
        );
        final offset = (y * image.width + x) * 4;
        return data!.buffer.asUint8List().sublist(offset, offset + 4);
      }

      final gradient = await render(1);
      final top = await pixel(gradient, 15, 10);
      final bottom = await pixel(gradient, 15, 190);
      expect(top[2], greaterThan(top[0]));
      expect(top[3], 255);
      expect(bottom, isNot([246, 246, 246, 255]));
      expect(bottom[3], 255);
      gradient.dispose();

      final plain = await render(0);
      expect(await pixel(plain, 15, 10), [246, 246, 246, 255]);
      expect(await pixel(plain, 15, 190), [246, 246, 246, 255]);
      plain.dispose();

      final solid = await render(1, style: AppBackgroundStyle.solid);
      expect(await pixel(solid, 15, 10), [246, 246, 246, 255]);
      expect(await pixel(solid, 15, 190), [246, 246, 246, 255]);
      solid.dispose();

      final singleGlow = await render(1, style: AppBackgroundStyle.singleGlow);
      final glowTop = await pixel(singleGlow, 15, 10);
      expect(glowTop[2], greaterThan(glowTop[0]));
      expect(await pixel(singleGlow, 15, 190), [246, 246, 246, 255]);
      singleGlow.dispose();
      expect(tester.takeException(), isNull);
    },
  );
}
