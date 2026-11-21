import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:petit_ornitho/data/game_store.dart';

Map<String, dynamic> read(String name) =>
    jsonDecode(File('assets/data/$name.json').readAsStringSync());

class ProgressionStore extends GameStore {
  ProgressionStore(
    super.prefs,
    super.content,
    super.media, {
    super.photoCatalog,
    super.knowledgeCatalog,
    super.speciesCatalog,
    super.progression,
  });
  @override
  String get identity => 'guest';
}

void main() {
  test('Photo choices respect unlock levels and themed habitat scope', () {
    final plan = read('progression');
    for (final q in read('content')['questions'] as List) {
      if (q['kind'] != 'photo') continue;
      final routes = q['route_stages'] as List? ?? [];
      if (routes.isEmpty) continue;
      final choices = q['option_species'];
      expect(choices, isA<List>(), reason: q['id']);
      expect(choices.length, q['options'].length, reason: q['id']);
      expect(choices[q['answer']], q['species_id'], reason: q['id']);
      for (final stage in routes.where((s) => s < 5)) {
        for (final id in [q['species_id'], ...choices]) {
          expect(plan['species_stages'][id], lessThanOrEqualTo(stage), reason: q['id']);
          // General discovery exercises introduce each species at its unlock
          // level without claiming it belongs to that level's habitat.
          if (!(q['id'] as String).startsWith('discovery_v1_')) {
            expect(plan['route_species']['$stage'], contains(id), reason: q['id']);
          }
        }
      }
    }
  });
  Future<GameStore> store() async {
    SharedPreferences.setMockInitialValues({});
    return GameStore(
      await SharedPreferences.getInstance(),
      read('content'),
      [],
      photoCatalog: read('photo_catalog'),
      knowledgeCatalog: read('knowledge_catalog'),
      learningRules: read('learning_rules'),
      speciesCatalog: read('species_catalog'),
      progression: read('progression'),
    );
  }

  test(
    'Existing chapter access preserves habitats without auto-unlocking after one series',
    () async {
      SharedPreferences.setMockInitialValues({});
      final content = read('content');
      content['questions'].addAll(
        jsonDecode(
          File('assets/data/journey_questions.json').readAsStringSync(),
        ),
      );
      final s = ProgressionStore(
        await SharedPreferences.getInstance(),
        content,
        [],
        photoCatalog: read('photo_catalog'),
        knowledgeCatalog: read('knowledge_catalog'),
        speciesCatalog: read('species_catalog'),
        progression: read('progression'),
      );
      s.reload();
      for (var stage = 1; stage <= 5; stage++) {
        // Fixture for a player with this chapter already unlocked.
        s.state['unlocked'] = stage;
        expect(s.unlocked, stage);
        expect(s.speciesAvailable('ch_1200'), stage >= 4);
        await s.start(stage);
        final size = (s.active!['ids'] as List).length;
        expect(size, inInclusiveRange(4, 6));
        Map<String, dynamic>? result;
        for (var i = 0; i < size; i++) {
          final q = s.current;
          expect(q.data['route_stages'], contains(stage));
          expect(s.speciesAvailable(q.species), isTrue);
          if (stage < 5 && q.kind == 'photo') {
            for (final id in q.data['option_species']) {
              expect(s.speciesAvailable(id), isTrue);
              if (!q.id.startsWith('discovery_v1_')) {
                expect(s.progression['route_species']['$stage'], contains(id));
              }
            }
          }
          await s.answer(q.answer);
          result = await s.next();
        }
        expect(result!['unlocked_pack'], isNull);
        expect(s.unlocked, stage);
        final xp = s.xp;
        expect(await s.next(), isNull);
        expect(s.xp, xp);
      }
      expect(s.playableSpecies.length, 293);
      expect(s.speciesAvailable('ch_3681'), isTrue);
    },
  );

  test(
    'Exact plan: 293 entries, excluded tiers absent, science provenance retained',
    () async {
      final s = await store();
      expect(s.species.length, 293);
      for (final (level, count) in [(1, 51), (2, 120), (3, 122)]) {
        expect(s.species.where((b) => b['level'] == level).length, count);
      }
      expect(s.species.where((b) => (b['level'] as int) > 3), isEmpty);
      expect(
        s.species.where((b) => b['taxonomy_status'] == 'needs_review').length,
        0,
      );
      expect(
        s.species
            .where((b) => b['presence'] != null && b['source_page'] != null)
            .length,
        293,
      );
      expect(
        s.species.firstWhere((b) => b['id'] == 'robin')['facts'],
        isNotEmpty,
      );
      expect(
        s.species.firstWhere((b) => b['id'] == 'ch_2630')['latin'],
        'Chroicocephalus ridibundus',
      );
    },
  );

  test(
    'All targets AND distractors follow cumulative player tiers; chrono stays without replacement',
    () async {
      final s = await store();
      for (final level in [1, 2, 3, 5]) {
        s.state['unlocked'] = level;
        final eligible = (s.photoCatalog['species'] as List)
            .where((b) => s.speciesAvailable(b['id']))
            .map((b) => b['id'])
            .toSet();
        String? last;
        for (var cycle = 0; cycle < 6; cycle++) {
          final deck = s.chronoRound(Random(level * 100 + cycle), last);
          expect(deck.length, eligible.length);
          expect(deck.map((q) => q.species).toSet(), eligible);
          expect(deck.first.species, isNot(last));
          for (final q in [...deck, ...s.photoRound(), ...s.learningRound()]) {
            expect(s.speciesAvailable(q.species), isTrue);
            for (final id in q.data['option_species'] ?? []) {
              expect(s.speciesAvailable(id), isTrue);
            }
          }
          last = deck.last.species;
        }
        expect(
          s.speciesAvailable('ch_3681'),
          isTrue,
        ); // Current Carrion Crow taxon, separately attested in Switzerland.
        expect(s.speciesAvailable('not-in-plan'), isFalse);
        expect(s.speciesAvailable('ch_1200'), level >= 4); // Raptor unlock.
        expect(
          s.speciesAvailable('ch_1680'),
          level >= 5,
        ); // Expert-tier Corncrake.
      }
    },
  );

  test(
    'A missing curriculum member cannot sneak in through bundled fallback content',
    () async {
      final s = await store();
      s.content['species'].add({
        'id': 'excluded',
        'name': 'Excluded',
        'latin': 'Testus excluded',
        'facts': [],
        'clues': [],
      });
      s.content['questions'].add({
        'id': 'excluded_q',
        'species_id': 'excluded',
        'kind': 'quiz',
      });
      expect(s.species.any((b) => b['id'] == 'excluded'), isFalse);
      expect(s.practiceQuestions.any((q) => q.species == 'excluded'), isFalse);
    },
  );
}
