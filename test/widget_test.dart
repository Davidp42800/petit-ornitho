import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:petit_ornitho/data/game_store.dart';
import 'package:petit_ornitho/ui/app.dart';

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
  testWidgets('Complete a guest session, save XP once and resume storage', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = GameStore(
      prefs,
      jsonDecode(File('assets/data/content.json').readAsStringSync()),
      jsonDecode(File('assets/data/media.json').readAsStringSync()),
    );
    store.reload();
    await tester.pumpWidget(OrnithoApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('Mon parcours'), findsOneWidget);
    await store.start(1);
    final first = store.active!['id'];
    await store.start(1);
    expect(store.active!['id'], first);
    for (var i = 0; i < 6; i++) {
      await store.answer(store.current.answer);
      await store.answer(store.current.answer);
      await store.next();
    }
    expect(store.xp, 90);
    expect(store.completed, 1);
    expect(store.unlocked, 1);
    expect(store.active, isNull);
    store.reload();
    expect(store.xp, 90);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  test(
    'Les questions retirées sont exclues des nouveaux tirages locaux',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final content = jsonDecode(
        File('assets/data/content.json').readAsStringSync(),
      );
      final store = GameStore(
        prefs,
        content,
        jsonDecode(File('assets/data/media.json').readAsStringSync()),
      );
      store.reload();
      await prefs.setStringList(
        'question_withdrawals_v1',
        store.questions
            .map((q) => '${q.id}@${q.data['version'] ?? 1}')
            .toList(),
      );
      await expectLater(store.start(1), throwsStateError);
      expect(store.active, isNull);
      expect(store.xp, 0);
    },
  );

  testWidgets('Question feedback survives closing and reopening', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = GameStore(
      prefs,
      jsonDecode(File('assets/data/content.json').readAsStringSync()),
      jsonDecode(File('assets/data/media.json').readAsStringSync()),
    );
    store.reload();
    await store.start(1);
    store.active!['ids'][0] = 'robin_photo';
    await store.answer(store.current.answer);
    store.reload();
    expect(store.active!['feedback']['correct'], isTrue);
    expect(store.active!['score'], 15);
    await tester.pumpWidget(MaterialApp(home: GameScreen(store: store)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Bien observé ! +15 plumes'), 250);
    expect(find.text('Bien observé ! +15 plumes'), findsOneWidget);
  });
  testWidgets('Carnet : coche réelle et filtre sans XP', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final store = GameStore(
      await SharedPreferences.getInstance(),
      jsonDecode(File('assets/data/content.json').readAsStringSync()),
      jsonDecode(File('assets/data/media.json').readAsStringSync()),
    );
    store.reload();
    await tester.pumpWidget(OrnithoApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mon carnet'));
    await tester.pumpAndSettle();
    expect(find.text('0 / 4 espèces cochées'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Mes espèces cochées'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mes espèces cochées'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Pas encore de coche.'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Mes espèces cochées'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mes espèces cochées'));
    await tester.pumpAndSettle();
    final bird = store.species.first['name'] as String;
    final mark = find.byKey(ValueKey('carnet-observation-${store.species.first['id']}'));
    await tester.ensureVisible(mark);
    await tester.tap(mark);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.descendant(of: mark, matching: find.text('Je l’ai vu !')), findsOneWidget);
    await tester.ensureVisible(mark);
    await tester.tap(mark);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Enregistrer ma coche'), 230, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Enregistrer ma coche'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Mes espèces cochées'));
    await tester.tap(find.text('Mes espèces cochées'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 4 espèces cochées'), findsOneWidget);
    expect(find.text(bird), findsOneWidget);
    expect(find.text('Vu en vrai'), findsOneWidget);
    expect(store.xp, 0);
    expect(store.mastery, isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Le parcours remplace les jeux libres et reprend la balade sauvegardée',
    (t) async {
      SharedPreferences.setMockInitialValues({});
      final store = GameStore(
        await SharedPreferences.getInstance(),
        jsonDecode(File('assets/data/content.json').readAsStringSync()),
        jsonDecode(File('assets/data/media.json').readAsStringSync()),
      );
      store.reload();
      await store.start(1);
      final before = jsonEncode(store.state);
      await t.pumpWidget(OrnithoApp(store: store));
      await t.pumpAndSettle();
      expect(find.text('Mon parcours'), findsOneWidget);
      await t.scrollUntilVisible(find.text('Étape 5 · Expert'), 180);
      expect(find.text('Choisis ton jeu'), findsNothing);
      expect(find.text('Jeu photo'), findsNothing);
      expect(find.text('Série chrono'), findsNothing);
      final locked = t.widget<ListTile>(
        find.widgetWithText(ListTile, 'Étape 5 · Expert'),
      );
      expect(locked.onTap, isNull);
      expect(jsonEncode(store.state), before);
      await t.scrollUntilVisible(find.text('Reprendre ma balade'), -180);
      await t.tap(find.text('Reprendre ma balade'));
      await t.pumpAndSettle();
      expect(find.byType(GameScreen), findsOneWidget);
      expect(jsonEncode(store.state), before);
      expect(t.takeException(), isNull);
    },
  );
}
