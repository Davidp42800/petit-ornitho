import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:petit_ornitho/data/game_store.dart';
import 'package:petit_ornitho/ui/app.dart';
import 'package:petit_ornitho/ui/practice_screen.dart';

// Fixed, source-backed fixtures keep lifecycle tests independent of catalogue growth.
Map<String, dynamic> practiceFixture(String kind) {
  final content = jsonDecode(File('assets/data/content.json').readAsStringSync())
      as Map<String, dynamic>;
  content['questions'] = (content['questions'] as List)
      .where((q) => q['kind'] == kind && q['format'] == null)
      .take(2)
      .toList();
  assert((content['questions'] as List).length == 2);
  return content;
}

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
  for (final kind in ['photo', 'match', 'mystery', 'quiz']) {
    testWidgets(
      '$kind: finish, replay and exit without changing saved progress',
      (t) async {
        t.view.physicalSize = const Size(390, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        final store = GameStore(
          await SharedPreferences.getInstance(),
          practiceFixture(kind),
          [],
        );
        store.reload();
        store.state['active'] = {
          'id': 'saved-journey', 'level': 1, 'index': 1, 'score': 15,
          'ids': ['saved-question-a', 'saved-question-b'], 'answers': [true],
          'hints': 1,
        };
        await store.save();
        final before = jsonEncode(store.state);
        await t.pumpWidget(
          MaterialApp(
            home: PracticeScreen(store: store, kind: kind),
          ),
        );
        await t.pumpAndSettle();
        final questions = store.questions.where((q) => q.kind == kind).toList();
        for (var i = 0; i < questions.length; i++) {
          final q = questions[i];
          if (kind == 'mystery') {
            for (final letter in q.options[q.answer].toUpperCase().split('')
                .where((c) => RegExp(r'[A-ZÀ-ÖØ-Ý]').hasMatch(c))) {
              final key = find.byWidgetPredicate((w) => w is OutlinedButton &&
                  w.key.toString().contains('bank-letter-') &&
                  w.onPressed != null && w.child is Text &&
                  (w.child as Text).data == letter).first;
              await t.ensureVisible(key);
              await t.pumpAndSettle();
              await t.tap(key);
              await t.pumpAndSettle();
            }
          } else {
          final answer = find.text(q.options[q.answer]);
          await t.scrollUntilVisible(
            answer,
            180,
            scrollable: find.byType(Scrollable).first,
          );
          await t.pumpAndSettle();
          await t.tap(answer);
          await t.pumpAndSettle();
          if (kind == 'match') {
            await t.tap(find.text('Valider mon choix'));
            await t.pumpAndSettle();
          }
          }
          final label = i == questions.length - 1
              ? 'Terminer le jeu'
              : (kind == 'photo' || kind == 'match')
              ? 'Oiseau suivant →'
              : 'Continuer →';
          await t.tap(find.text(label));
          await t.pumpAndSettle();
        }
        expect(find.text('Bravo, partie terminée !'), findsOneWidget);
        expect(find.text('${questions.length} / ${questions.length} bonnes réponses'), findsOneWidget);
        final journey = Map<String, dynamic>.from(store.state)
          ..remove('skills')
          ..remove('learning_attempts');
        expect(jsonEncode(journey), before);
        expect(store.attempts.length, questions.length);
        await t.tap(find.text('Rejouer'));
        await t.pumpAndSettle();
        expect(find.textContaining(RegExp('jeu libre · 1/${questions.length}', caseSensitive: false)), findsOneWidget);
        expect(t.takeException(), isNull);
      },
    );
  }
  testWidgets('Account access remains separate from the journey', (
    t,
  ) async {
    final store = GameStore(
      await SharedPreferences.getInstance(),
      jsonDecode(File('assets/data/content.json').readAsStringSync()),
      [],
    );
    store.reload();
    await t.pumpWidget(OrnithoApp(store: store));
    await t.pumpAndSettle();
    expect(find.text('Se connecter'), findsNothing);
    await t.tap(find.byTooltip('Mon compte'));
    await t.pumpAndSettle();
    expect(find.text('Se connecter'), findsOneWidget);
    expect(find.text('Pépi et l’assistant IA'), findsOneWidget);
  });
  testWidgets('Changing stages never silently resumes a different stage', (
    t,
  ) async {
    t.view.physicalSize = const Size(1000, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final store = GameStore(
      await SharedPreferences.getInstance(),
      jsonDecode(File('assets/data/content.json').readAsStringSync()),
      [],
    );
    store.reload();
    await store.start(1);
    store.state['unlocked'] = 2;
    final before = jsonEncode(store.state);
    await t.pumpWidget(OrnithoApp(store: store));
    await t.pumpAndSettle();
    await t.tap(find.text('Étape 2 · Aventurier').last);
    await t.pumpAndSettle();
    expect(find.text('Une balade t’attend'), findsOneWidget);
    await t.tap(find.text('Rester ici'));
    await t.pumpAndSettle();
    expect(jsonEncode(store.state), before);
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'Navigation and game help fit at large text on a narrow phone',
    (t) async {
      t.view.physicalSize = const Size(320, 740);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final store = GameStore(
        await SharedPreferences.getInstance(),
        jsonDecode(File('assets/data/content.json').readAsStringSync()),
        [],
      );
      store.reload();
      for (final kind in ['mystery', 'quiz']) {
        await t.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(2)),
              child: child!,
            ),
            home: PracticeScreen(key: ValueKey(kind), store: store, kind: kind),
          ),
        );
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      }
    },
  );
}
