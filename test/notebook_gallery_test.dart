import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:petit_ornitho/data/game_store.dart';
import 'package:petit_ornitho/ui/app.dart';
import 'package:petit_ornitho/ui/bird_photo.dart';

void main() {
  testWidgets('Notebook portraits open details and an observation editor', (
    t,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test',
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
      ),
    );
    t.view.physicalSize = const Size(734, 977);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    for (final e in {
      'Avenir': '/System/Library/Fonts/Avenir Next.ttc',
      'MaterialIcons':
          '/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(e.key)..addFont(
            Future.value(ByteData.sublistView(File(e.value).readAsBytesSync())),
          ))
          .load();
    }
    dynamic read(String p) =>
        jsonDecode(File('assets/data/$p.json').readAsStringSync());
    final store = GameStore(
      await SharedPreferences.getInstance(),
      read('content'),
      read('media'),
      photoCatalog: read('photo_catalog'),
      speciesCatalog: read('species_catalog'),
      progression: read('progression'),
      publishedFacts: read('published_species_facts')['facts'],
    )..reload();
    final key = GlobalKey();
    await t.pumpWidget(
      RepaintBoundary(
        key: key,
        child: OrnithoApp(store: store),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Mon carnet'));
    await t.pumpAndSettle();
    await t.runAsync(() async {
      for (final p in [
        'assets/art/swiss-garden-v1.png',
        'assets/art/pio-evolution-v1.png',
        for (final bird in store.species.take(24))
          if (store.photoFor(bird['id']) != null)
            bundledBirdAsset(store.photoFor(bird['id'])!['asset']),
      ]) {
        await precacheImage(AssetImage(p), key.currentContext!);
      }
    });
    await t.pumpAndSettle();
    Future<void> capture(String name) async {
      await t.runAsync(() async {
        final im =
            await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = await im.toByteData(format: ui.ImageByteFormat.png);
        File(
          'docs/screenshots/$name.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
        im.dispose();
      });
    }

    await capture('notebook-gallery');
    expect(find.text('Je l’ai vu !'), findsWidgets);
    await t.enterText(find.byType(TextField), 'Grèbe huppé');
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Grèbe huppé').last);
    await t.tap(find.text('Grèbe huppé').last);
    await t.pumpAndSettle();
    expect(find.text('Je l’ai vu !'), findsOneWidget);
    await t.ensureVisible(find.text('Je l’ai vu !'));
    await t.tap(find.text('Je l’ai vu !'));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
      find.text('Utiliser ma position actuelle'),
      150,
      scrollable: find
          .descendant(
            of: find.byType(ListView).last,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
}
