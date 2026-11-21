import 'test_paths.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:petit_ornitho/data/game_store.dart';
import 'package:petit_ornitho/ui/game_screen.dart';
import 'package:petit_ornitho/ui/hidden_name_input.dart';

class LocalStore extends GameStore {
  LocalStore(super.prefs, super.content, super.media);
  @override
  String get identity => 'guest';
}

void main() {
  testWidgets(
    'saved journey renders letters and persists helped answers on mobile',
    (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final content = jsonDecode(
        File('assets/data/content.json').readAsStringSync(),
      );
      final store = LocalStore(
        await SharedPreferences.getInstance(),
        content,
        [],
      )..reload();
      store.state = {
        'unlocked': 3,
        'active': {
          'id': 'test-letters',
          'level': 3,
          'index': 0,
          'ids': ['blue_tit_mystery', 'robin_mystery'],
          'hints': 1,
          'score': 0,
          'answers': [],
          'feedback': null,
        },
      };
      for (final entry in {
        'Avenir': testAvenirPath(),
        'MaterialIcons':
            testFontPath('MaterialIcons-Regular.otf'),
      }.entries) {
        final file = File(entry.value);
        if (file.existsSync()) {
          await (FontLoader(entry.key)..addFont(
                Future.value(ByteData.sublistView(file.readAsBytesSync())),
              ))
              .load();
        }
      }
      final boundary = GlobalKey();
      await t.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            theme: ThemeData(fontFamily: 'Avenir'),
            home: GameScreen(store: store),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byType(HiddenNameInput), findsOneWidget);
      expect(find.text('Mésange bleue'), findsNothing);
      await t.ensureVisible(find.text('Découvrir une lettre'));
      await t.tap(find.text('Découvrir une lettre'));
      await t.pumpAndSettle();
      expect(store.active!['assisted'], true);
      expect(find.textContaining('Pépi t’a apporté la lettre'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is Text && RegExp(r'^[A-ZÉÈÊ]$').hasMatch(w.data ?? ''),
        ),
        findsWidgets,
      );
      expect(t.takeException(), isNull);
      // Capture actual journey layout after the short flight, not a mock screen.
      if (Platform.isMacOS) {
        await t.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File(
            'docs/screenshots/journey-hidden-name.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      const name = 'MÉSANGE BLEUE';
      for (var i = 0; i < name.length; i++) {
        if (name[i] == ' ' || store.active?['feedback'] != null) continue;
        final slot = find.byKey(ValueKey('letter-slot-$i'));
        if (t.widget<OutlinedButton>(slot).onPressed == null) continue;
        await t.ensureVisible(slot);
        await t.tap(slot);
        await t.pump();
        final letter = find.byWidgetPredicate(
          (w) =>
              w is OutlinedButton &&
              w.key.toString().contains('bank-letter') &&
              w.onPressed != null &&
              w.child is Text &&
              (w.child as Text).data == name[i],
        );
        await t.ensureVisible(letter.first);
        await t.tap(letter.first);
        await t.pumpAndSettle();
      }
      expect(find.text('Je propose ce nom'), findsNothing);
      await t.pumpAndSettle();
      expect(store.active!['feedback']['correct'], true);
      expect(store.attempts.last['assisted'], true);
      store.reload();
      expect(store.active!['feedback']['correct'], true);
      expect(store.attempts.last['assisted'], true);
      expect(find.byType(HiddenNameInput), findsNothing);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
    },
  );
}
