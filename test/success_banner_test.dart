import 'test_paths.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petit_ornitho/ui/game_effects.dart';
import 'package:petit_ornitho/ui/success_banner.dart';

void main() {
  setUpAll(() async {
    for (final entry in {
      'Roboto': 'Roboto-Regular.ttf',
      'MaterialIcons': 'MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(entry.key)..addFont(
            Future.value(
              ByteData.sublistView(
                File(
                  testFontPath('${entry.value}'),
                ).readAsBytesSync(),
              ),
            ),
          ))
          .load();
    }
  });
  testWidgets(
    'Bravo is responsive, finite, decorative and respects reduced motion',
    (t) async {
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.view.resetPhysicalSize);
      for (final width in [320.0, 837.0]) {
        for (final scale in [1.0, 1.7]) {
          t.view.physicalSize = Size(width, 600);
          var taps = 0;
          final key = GlobalKey();
          Widget page({bool reduced = false}) => RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                  disableAnimations: reduced,
                ),
                child: child!,
              ),
              home: Scaffold(
                body: GameEffects(
                  event: 'success',
                  success: true,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: TextButton(
                      onPressed: () => taps++,
                      child: const Text('Continuer'),
                    ),
                  ),
                ),
              ),
            ),
          );
          await t.pumpWidget(page());
          await t.pump(const Duration(milliseconds: 900));
          expect(find.byType(SuccessBanner), findsOneWidget);
          expect(find.text('Bravo !'), findsOneWidget);
          expect(t.takeException(), isNull);
          await t.runAsync(() async {
            final image =
                await (key.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final dir = Directory('docs/screenshots/2026-10-25-bravo');
            await dir.create(recursive: true);
            await File(
              '${dir.path}/bravo-${width.toInt()}-$scale.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
          await t.tap(find.text('Continuer'));
          expect(taps, 1);
          await t.pumpAndSettle();
          expect(find.byType(SuccessBanner), findsNothing);
          expect(t.hasRunningAnimations, isFalse);
          await t.pumpWidget(page(reduced: true));
          await t.pump();
          expect(find.byType(SuccessBanner), findsNothing);
          await t.pumpWidget(const SizedBox());
        }
      }
    },
  );
}
