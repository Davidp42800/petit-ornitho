import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:petit_ornitho/data/game_store.dart';
import 'package:petit_ornitho/ui/app.dart';
import 'package:petit_ornitho/ui/auth_screen.dart';
import 'package:petit_ornitho/ui/hidden_bird_screen.dart';
import 'package:petit_ornitho/ui/listening_screen.dart';
import 'package:petit_ornitho/ui/sighting_editor.dart';
import 'package:petit_ornitho/data/sightings.dart';

void main() {
  testWidgets('Revue visuelle : carnet, profil, formulaires, quiz et mystère', (
    t,
  ) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test',
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
      ),
    );
    for (final entry in {
      'Avenir': '/System/Library/Fonts/Avenir Next.ttc',
      'MaterialIcons':
          '/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    }.entries) {
      final f = File(entry.value);
      if (f.existsSync()) {
        await (FontLoader(
              entry.key,
            )..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync()))))
            .load();
      }
    }
    final store = GameStore(
      await SharedPreferences.getInstance(),
      jsonDecode(File('assets/data/content.json').readAsStringSync()),
      jsonDecode(File('assets/data/media.json').readAsStringSync()),
    );
    store.reload();
    final key = GlobalKey();
    await t.pumpWidget(
      RepaintBoundary(
        key: key,
        child: OrnithoApp(store: store),
      ),
    );
    await t.pumpAndSettle();
    await t.runAsync(() async {
      for (final path in [
        'assets/art/swiss-garden-v1.png',
        'assets/art/pio-evolution-v1.png',
        ...store.species.map((b) => 'assets/birds/${b['id']}.jpg'),
      ]) {
        await precacheImage(AssetImage(path), key.currentContext!);
      }
    });
    await t.pumpAndSettle();
    Future<void> capture(String name) async {
      expect(t.takeException(), isNull);
      if (!Platform.isMacOS) return;
      await t.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          'docs/screenshots/review-$name.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await capture('home');
    await t.tap(find.text('Mon carnet'));
    await t.pumpAndSettle();
    await capture('notebook');
    await t.tap(find.text('Pépi & moi'));
    await t.pumpAndSettle();
    await capture('profile');
    final app = t.widget<MaterialApp>(find.byType(MaterialApp));
    Future<void> screen(Widget page, String name, {double scale = 1}) async {
      await t.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: app.theme,
            locale: app.locale,
            supportedLocales: app.supportedLocales,
            localizationsDelegates: app.localizationsDelegates,
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(390, 844),
                textScaler: TextScaler.linear(scale),
              ),
              child: page,
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await capture(name);
    }

    await screen(HiddenBirdScreen(store: store), 'hidden-start');
    await t.scrollUntilVisible(find.text('Z'), 160);
    await t.ensureVisible(find.text('Z'));
    await t.pumpAndSettle();
    await t.tap(find.text('Z'));
    await t.pumpAndSettle();
    await capture('hidden-wrong-letter');
    while (find.textContaining('Bravo !').evaluate().isEmpty) {
      await t.scrollUntilVisible(find.text('Découvrir une lettre'), 150);
      await t.ensureVisible(find.text('Découvrir une lettre'));
      await t.pumpAndSettle();
      await t.tap(find.text('Découvrir une lettre'));
      await t.pumpAndSettle();
    }
    await capture('hidden-success');
    await screen(ListeningScreen(store: store), 'song-pending');
    await screen(AuthScreen(store: store), 'account');
    await screen(
      SightingEditor(
        sightings: Sightings(store.prefs, 'guest'),
        species: 'robin',
        name: 'Rougegorge familier',
      ),
      'sighting',
    );
    for (final kind in ['quiz', 'mystery']) {
      final q = store.questions.firstWhere((q) => q.kind == kind);
      store.state['active'] = {
        'id': 'review',
        'ids': [q.id],
        'index': 0,
        'score': 0,
        'level': 1,
        'hints': 1,
        'answers': [],
      };
      await screen(GameScreen(key: ValueKey(kind), store: store), kind);
    }
    await screen(AuthScreen(store: store), 'account-large', scale: 1.7);
    expect(t.takeException(), isNull);
  });
}
