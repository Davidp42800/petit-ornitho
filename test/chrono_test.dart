import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:petit_ornitho/data/game_store.dart';
import 'package:petit_ornitho/ui/chrono_screen.dart';
import 'package:petit_ornitho/ui/bird_photo.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test',
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
      ),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());
  testWidgets(
    '60s deadline, -3 penalty, first response only, local record and evidence',
    (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      Map<String, dynamic> read(String name) =>
          jsonDecode(File('assets/data/$name.json').readAsStringSync());
      final store = GameStore(
        prefs,
        read('content'),
        [],
        photoCatalog: read('photo_catalog'),
        learningRules: read('learning_rules'),
      )..reload();
      var clock = DateTime.utc(2026, 10, 3);
      await t.pumpWidget(
        MaterialApp(
          home: ChronoScreen(store: store, clock: () => clock),
        ),
      );
      await t.tap(find.text('Démarrer · Photos'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      expect(find.text('60 s'), findsOneWidget);
      final photo = t.widget<BirdPhoto>(find.byType(BirdPhoto));
      final target = store.species.firstWhere(
        (s) => s['id'] == photo.species,
      )['name'];
      final right = find.text(target);
      await t.ensureVisible(right);
      await t.tap(right);
      await t.tap(right);
      await t.pump();
      expect(find.text('1 point'), findsOneWidget);
      await t.pump(const Duration(milliseconds: 300));
      final newPhoto = t.widget<BirdPhoto>(find.byType(BirdPhoto));
      final newTarget = store.species.firstWhere(
        (s) => s['id'] == newPhoto.species,
      )['name'];
      final buttons = t.widgetList<FilledButton>(find.byType(FilledButton));
      final wrong =
          (buttons.firstWhere((b) => (b.child as Text).data != newTarget).child
                  as Text)
              .data!;
      await t.ensureVisible(find.text(wrong));
      await t.tap(find.text(wrong));
      await t.pump();
      expect(find.text('57 s'), findsOneWidget);
      clock = clock.add(const Duration(seconds: 58));
      await t.pump(const Duration(milliseconds: 400));
      await t.pumpAndSettle();
      expect(find.text('1 oiseau reconnu !'), findsOneWidget);
      expect(prefs.getInt('ornitho_chrono_photo_v1_guest'), 1);
      expect(store.attempts.length, 2);
      expect(store.xp, 0);
      expect(find.textContaining(RegExp(r'^(À observer sur cette photo|Le détail qui les distingue)$')), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
}
