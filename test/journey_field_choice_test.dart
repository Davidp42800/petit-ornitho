import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:petit_ornitho/data/game_store.dart';
import 'package:petit_ornitho/ui/game_screen.dart';
import 'package:petit_ornitho/ui/field_choice.dart';
import 'package:petit_ornitho/ui/bird_photo.dart';

class FieldStore extends GameStore {
  FieldStore(
    super.prefs,
    super.content,
    super.media, {
    super.photoCatalog,
    super.publishedFacts,
  });
  @override
  String get identity => 'guest';
}

void main() {
  testWidgets(
    'A generic knowledge quiz shows its species photo without a topic title',
    (t) async {
      SharedPreferences.setMockInitialValues({});
      dynamic read(String p) => jsonDecode(File(p).readAsStringSync());
      final content = read('assets/data/content.json');
      final store = FieldStore(
        await SharedPreferences.getInstance(),
        content,
        [],
        photoCatalog: read('assets/data/photo_catalog.json'),
        publishedFacts: [],
      )..reload();
      final q = store.questions.firstWhere(
        (q) =>
            q.kind == 'quiz' &&
            q.data['format'] != 'ranking' &&
            store.photoFor(q.species) != null,
      );
      store.state = {
        'unlocked': 1,
        'active': {
          'id': 'generic-photo',
          'level': 1,
          'index': 0,
          'ids': [q.id],
          'hints': 0,
          'score': 0,
          'answers': [],
          'feedback': null,
        },
      };
      await t.pumpWidget(MaterialApp(home: GameScreen(store: store)));
      await t.pumpAndSettle();
      expect(find.byType(BirdPhoto), findsOneWidget);
      expect(t.widget<BirdPhoto>(find.byType(BirdPhoto)).species, q.species);
      expect(find.text('Source et crédit photo'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'Saved nest mission uses placement and persists its graded answer',
    (t) async {
      SharedPreferences.setMockInitialValues({});
      dynamic read(String p) => jsonDecode(File(p).readAsStringSync());
      final content = read('assets/data/content.json');
      final store = FieldStore(
        await SharedPreferences.getInstance(),
        content,
        [],
        photoCatalog: read('assets/data/photo_catalog.json'),
        publishedFacts: read(
          'assets/data/published_species_facts.json',
        )['facts'],
      )..reload();
      store.state = {
        'unlocked': 2,
        'active': {
          'id': 'test-nest-placement',
          'level': 2,
          'index': 0,
          'ids': ['pio_nest_ch_3320_v1', 'pio_nest_ch_80_v1'],
          'hints': 0,
          'score': 0,
          'answers': [],
          'feedback': null,
        },
      };
      final answer = store.current.answer;
      await t.pumpWidget(MaterialApp(home: GameScreen(store: store)));
      await t.pumpAndSettle();
      expect(find.text('Où est mon nid ?'), findsOneWidget);
      expect(find.byType(FieldChoice), findsOneWidget);
      final wrong = (answer + 1) % store.current.options.length;
      await t.ensureVisible(find.byKey(ValueKey('field-option-$wrong')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(ValueKey('field-option-$wrong')));
      await t.pumpAndSettle();
      expect(store.active!['feedback']['correct'], false);
      final attemptsBeforeCorrection = store.attempts.length;
      final choice = find.byKey(ValueKey('field-option-$answer'));
      await t.ensureVisible(choice);
      await t.pumpAndSettle();
      await t.tap(choice);
      await t.pump();
      await t.pumpAndSettle();
      expect(store.active!['feedback']['correct'], false);
      expect(store.attempts.length, attemptsBeforeCorrection);
      expect(store.active!['score'], 0);
      expect(find.byKey(const ValueKey('revealed-correct-answer')), findsOneWidget);
      expect(find.text('Je valide mon choix'), findsNothing);
      expect(find.text('Explique-moi'), findsNothing);
      expect(find.byType(FieldChoice), findsNothing);
      store.reload();
      expect(store.active!['feedback']['correct'], false);
      expect(store.attempts.length, attemptsBeforeCorrection);
      expect(store.active!['score'], 0);
      expect(find.byKey(const ValueKey('revealed-correct-answer')), findsOneWidget);
      expect(find.text('Je valide mon choix'), findsNothing);
      expect(find.text('Explique-moi'), findsNothing);
      expect(t.takeException(), isNull);
      await t.pump(const Duration(seconds: 2));
      await t.pumpAndSettle();
      expect(store.active!['index'], 0);
      final next = find.text('Continuer →');
      await t.ensureVisible(next);
      await t.tap(next);
      await t.pumpAndSettle();
      expect(store.active!['index'], 1);
      await t.pumpWidget(const SizedBox.shrink());
    },
  );
}
