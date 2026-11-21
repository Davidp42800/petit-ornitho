import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:petit_ornitho/data/game_store.dart';
import 'package:petit_ornitho/domain/game.dart';
import 'package:petit_ornitho/ui/naturalist_guide.dart';
import 'package:petit_ornitho/ui/practice_screen.dart';
import 'package:petit_ornitho/ui/bird_photo.dart';

Map<String, dynamic> read(String file) =>
    jsonDecode(File(file).readAsStringSync());
void main() {
  final knowledge = read('assets/data/knowledge_catalog.json');
  final photos = read('assets/data/photo_catalog.json');
  final base = read('assets/data/content.json');
  test(
    'Chrono traverses all species before repeats, even with overdue mastery',
    () async {
      SharedPreferences.setMockInitialValues({});
      final rules = read('assets/data/learning_rules.json');
      final store = GameStore(
        await SharedPreferences.getInstance(),
        base,
        [],
        photoCatalog: photos,
        learningRules: rules,
      );
      store.state['skills'] = {
        'ch_720:visual': {'due_at': '2000-01-01T00:00:00Z'},
      };
      final eligible = (photos['species'] as List)
          .where((b) => (rules['launch_species'] as List).contains(b['id']))
          .map((b) => b['id'])
          .toSet();
      final random = Random(91);
      String? previous;
      for (var cycle = 0; cycle < 20; cycle++) {
        final deck = store.chronoRound(random, previous);
        expect(deck.map((q) => q.species).toSet(), eligible);
        expect(deck.length, eligible.length);
        expect(deck.where((q) => q.species == 'ch_720').length, 1);
        expect(deck.first.species, isNot(previous));
        previous = deck.last.species;
      }
    },
  );
  test(
    'Published content references Swiss taxa, exact documents and reviewed photos',
    () {
      final swiss =
          (read('docs/sources/swiss-checklist-2026.json')['species'] as List)
              .where((s) => s['category'] != 'D')
              .map((s) => s['latin'])
              .toSet();
      for (final bird in [...knowledge['species'], ...photos['species']]) {
        expect(swiss, contains(bird['latin']));
      }
      final facts = {for (final f in knowledge['facts']) f['id']: f};
      final documents = {for (final d in knowledge['documents']) d['id']: d};
      for (final q in knowledge['questions']) {
        final f = facts[q['fact_id']]!;
        expect(f['species_id'], q['species_id']);
        expect(documents[f['document_id']]['review_status'], isNot('blocked'));
        if (f['page'] != null) {
          expect(q['source'], endsWith('#page=${f['page']}'));
        } else {
          expect(f['source_locator'], isNotEmpty);
          expect(Uri.parse(q['source']).scheme, 'https');
          expect(
            documents[f['document_id']]['sha256'],
            matches(RegExp(r'^[a-f0-9]{64}$')),
          );
        }
        expect(q['options'][q['answer']], isA<String>());
        expect(guideHint(Question(Map<String, dynamic>.from(q))), q['hint']);
      }
      for (final bird in photos['species']) {
        for (final photo in bird['photos']) {
          expect(photo['status'], 'reviewed');
          expect(File(photo['asset']).existsSync(), isTrue);
          expect(photo['author'], isNotEmpty);
          final b = photo['subject'] as List;
          final size = Size(
            (photo['dimensions']['width'] as num).toDouble(),
            (photo['dimensions']['height'] as num).toDouble(),
          );
          final subject = Rect.fromLTRB(
            (b[0] as num).toDouble(),
            (b[1] as num).toDouble(),
            (b[2] as num).toDouble(),
            (b[3] as num).toDouble(),
          );
          for (final viewport in [const Size(280, 230), const Size(700, 300)]) {
            final frame = framedImageRect(viewport, size, subject);
            final mapped = Rect.fromLTRB(
              frame.left + subject.left * frame.width,
              frame.top + subject.top * frame.height,
              frame.left + subject.right * frame.width,
              frame.top + subject.bottom * frame.height,
            );
            expect(
              (mapped.center - Offset(viewport.width / 2, viewport.height / 2))
                  .distance,
              lessThan(.001),
            );
            expect(mapped.left, greaterThanOrEqualTo(0));
            expect(mapped.right, lessThanOrEqualTo(viewport.width));
            expect(mapped.top, greaterThanOrEqualTo(0));
            expect(mapped.bottom, lessThanOrEqualTo(viewport.height));
          }
        }
      }
    },
  );
  test(
    'Photo rounds vary images and species without changing the saved journey',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = GameStore(
        await SharedPreferences.getInstance(),
        base,
        [],
        photoCatalog: photos,
        knowledgeCatalog: knowledge,
      );
      store.state = {
        'xp': 120,
        'unlocked': 3,
        'active': {'id': 'existing'},
      };
      final before = jsonEncode(store.state);
      final seen = <String>{};
      for (var i = 0; i < 100; i++) {
        final round = store.photoRound(Random(i));
        expect(round.map((q) => q.species).toSet().length, 4);
        for (final q in round) {
          final bird = store.species.firstWhere((b) => b['id'] == q.species);
          expect(q.options[q.answer], bird['name']);
          seen.add(q.id);
        }
      }
      expect(seen.length, greaterThan(21));
      expect(store.learningRound().length, 6);
      expect(jsonEncode(store.state), before);
    },
  );
  testWidgets(
    'New scientific quiz shows a contextual Pépi hint and source after answer',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final one = Map<String, dynamic>.from(knowledge)
        ..['questions'] = [knowledge['questions'][0]];
      final store = GameStore(
        await SharedPreferences.getInstance(),
        base,
        [],
        knowledgeCatalog: one,
      );
      final q = Question(Map<String, dynamic>.from(one['questions'][0]));
      await tester.pumpWidget(
        MaterialApp(
          home: PracticeScreen(store: store, kind: 'quiz'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(q.prompt), findsOneWidget);
      await tester.ensureVisible(find.text('Aide de Pépi'));
      await tester.tap(find.text('Aide de Pépi'));
      await tester.pumpAndSettle();
      expect(find.text(q.data['hint']), findsOneWidget);
      await tester.tap(find.byTooltip('Fermer le guide'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(q.options[q.answer]));
      await tester.tap(find.text(q.options[q.answer]));
      await tester.pumpAndSettle();
      expect(find.text(q.explanation), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
