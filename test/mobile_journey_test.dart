import 'test_paths.dart';
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

void main() {
  testWidgets('Phone touch journey, feedback and completion', (t) async {
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
    final font = File(testAvenirPath());
    if (font.existsSync()) {
      final loader = FontLoader('Avenir')
        ..addFont(Future.value(ByteData.sublistView(font.readAsBytesSync())));
      await loader.load();
    }
    for (final entry in {
      'MaterialIcons': 'MaterialIcons-Regular.otf',
      'Roboto': 'Roboto-Regular.ttf',
    }.entries) {
      final f = File(
        testFontPath('${entry.value}'),
      );
      if (f.existsSync()) {
        final loader = FontLoader(entry.key)
          ..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
        await loader.load();
      }
    }
    final store = GameStore(
      await SharedPreferences.getInstance(),
      jsonDecode(File('assets/data/content.json').readAsStringSync()),
      jsonDecode(File('assets/data/media.json').readAsStringSync()),
    );
    store.reload();
    await store.start(1);
    store.state['active']['ids'] = store.questions
        .where((q) => q.kind == 'photo' && q.data['format'] == null)
        .take(6).map((q) => q.id).toList();
    await store.save();
    final key = GlobalKey();
    await t.pumpWidget(
      RepaintBoundary(
        key: key,
        child: OrnithoApp(store: store),
      ),
    );
    await t.pumpAndSettle();
    Future<void> capture(String name) async {
      if (!Platform.isMacOS) return;
      await t.runAsync(() async {
        final b =
            key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await b.toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('docs/screenshots').create(recursive: true);
        await File(
          'docs/screenshots/$name.png',
        ).writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }

    await t.runAsync(() async {
      await precacheImage(
        const AssetImage('assets/art/swiss-garden-v1.png'),
        key.currentContext!,
      );
      for (final id in ['robin', 'blackbird', 'blue_tit', 'goldfinch']) {
        await precacheImage(
          AssetImage('assets/birds/$id.jpg'),
          key.currentContext!,
        );
      }
    });
    await t.pumpAndSettle();
    await capture('home');
    await t.ensureVisible(
      find.widgetWithText(FilledButton, 'Reprendre ma balade'),
    );
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Reprendre ma balade'));
    await t.pumpAndSettle();
    await t.tap(find.text('Reprendre ma balade'));
    await t.pumpAndSettle();
    for (var i = 0; i < 6; i++) {
      final q = store.current;
      final option =
          q.options[i == 0 ? (q.answer + 1) % q.options.length : q.answer];
      await t.scrollUntilVisible(find.text(option), 180);
      await t.ensureVisible(find.text(option));
      await t.pumpAndSettle();
      await t.tap(find.text(option));
      await t.pumpAndSettle();
      if (i == 0) {
        expect(store.active!['feedback']['correct'], isFalse);
        await capture('feedback');
        final correct = find.text(q.options[q.answer]);
        await t.ensureVisible(correct);
        await t.tap(correct);
        await t.pumpAndSettle();
      }
      final next = find.text(i == 5 ? 'Découvrir mon bilan' : 'Continuer →');
      await t.tap(next);
      await t.pumpAndSettle();
    }
    expect(find.text('Une belle envolée !'), findsOneWidget);
    expect(find.text('Pépi a grandi grâce à toi !'), findsNothing);
    expect(store.unlocked, 1);
    expect(store.xp, 75);
    expect(store.completed, 1);
    await capture('result');
    expect(t.takeException(), isNull);
  });
}
