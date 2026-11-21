import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petit_ornitho/ui/bird_photo.dart';

void main() {
  test(
    'Every published photo is bundled, including old snapshot paths',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final catalog = jsonDecode(
        File('assets/data/photo_catalog.json').readAsStringSync(),
      );
      for (final bird in catalog['species']) {
        for (final photo in bird['photos']) {
          final asset = photo['asset'] as String;
          expect(
            (await rootBundle.load(bundledBirdAsset(asset))).lengthInBytes,
            greaterThan(0),
          );
          if (asset.startsWith('assets/birds/reviewed/')) {
            expect(
              bundledBirdAsset(asset.replaceFirst('/reviewed/', '/catalog/')),
              asset,
            );
          }
        }
      }
    },
  );
  testWidgets('Fourth beginner lot: actual photo framing at card size', (
    t,
  ) async {
    t.view.physicalSize = const Size(720, 850);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final selected =
        jsonDecode(
              File(
                const String.fromEnvironment('PHOTO_SELECTION', defaultValue: 'data/editorial/beginner-photo-fourth-selections.json'),
              ).readAsStringSync(),
            )
            as Map;
    t.view.physicalSize = Size(720, ((selected.length + 1) ~/ 2) * 280.0 + 20);
    final birds =
        jsonDecode(
              File('assets/data/photo_catalog.json').readAsStringSync(),
            )['species']
            as List;
    final photos = [
      for (final bird in birds)
        for (final photo in bird['photos'])
          if (selected.containsKey(photo['id'])) {'bird': bird, 'photo': photo},
    ];
    expect(photos.length, selected.length);
    final font = File('/System/Library/Fonts/Avenir Next.ttc');
    if (font.existsSync()) {
      await (FontLoader('Avenir')..addFont(
            Future.value(ByteData.sublistView(font.readAsBytesSync())),
          ))
          .load();
    }
    final key = GlobalKey();
    await t.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(fontFamily: 'Avenir'),
          home: Scaffold(
            body: GridView.count(
              crossAxisCount: 2,
              childAspectRatio: 1.3,
              children: [
                for (final row in photos)
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(row['bird']['name']),
                        ),
                        BirdPhoto(
                          species: row['bird']['id'],
                          media: Map<String, dynamic>.from(row['photo']),
                          height: 220,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await t.runAsync(() async {
      for (final row in photos) {
        await precacheImage(
          AssetImage(row['photo']['asset']),
          key.currentContext!,
        );
      }
    });
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    if (Platform.isMacOS) {
      await t.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File(
          const String.fromEnvironment('PHOTO_SCREENSHOT', defaultValue: 'docs/screenshots/beginner-fourth-photos.png'),
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
