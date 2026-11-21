import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:petit_ornitho/domain/game.dart';

void main() {
  test(
    'First walk includes familiar songs but rejects alarms and harder species',
    () {
      final pool = [
        for (var i = 0; i < 8; i++)
          Question({'id': 'p$i', 'kind': 'photo', 'species_id': 'bird$i'}),
        for (final entry in {
          'blackbird': 'song',
          'ch_3020': 'song',
          'ch_3681': 'call',
        }.entries)
          Question({
            'id': entry.key,
            'kind': 'audio',
            'species_id': entry.key,
            'recording': {'type': entry.value},
          }),
        Question({
          'id': 'alarm',
          'kind': 'audio',
          'species_id': 'blackbird',
          'recording': {'type': 'alarm'},
        }),
        Question({
          'id': 'expert',
          'kind': 'audio',
          'species_id': 'other',
          'recording': {'type': 'song'},
        }),
      ];
      for (var seed = 0; seed < 40; seed++) {
        final ids = SessionGenerator(Random(seed)).generate(pool, {}, 1);
        expect(
          ids.any((id) => {'blackbird', 'ch_3020', 'ch_3681'}.contains(id)),
          isTrue,
        );
        expect(ids, isNot(contains('alarm')));
        expect(ids, isNot(contains('expert')));
      }
    },
  );
  test('Hundreds of migration questions do not dominate a varied series', () {
    final candidates = [
      for (var i = 0; i < 287; i++)
        Question({
          'id': 'pio_migration_$i',
          'kind': 'quiz',
          'species_id': 'm$i',
        }),
      for (var i = 0; i < 6; i++)
        Question({'id': 'nest_$i', 'kind': 'quiz', 'species_id': 'n$i'}),
      Question({'id': 'photo', 'kind': 'photo', 'species_id': 'visual'}),
      Question({'id': 'audio', 'kind': 'audio', 'species_id': 'sound'}),
      Question({'id': 'mystery', 'kind': 'mystery', 'species_id': 'hidden'}),
    ];
    for (var seed = 0; seed < 50; seed++) {
      final ids = SessionGenerator(Random(seed)).generate(candidates, {}, 5);
      expect(
        ids.where((id) => id.startsWith('pio_migration_')).length,
        lessThanOrEqualTo(1),
      );
      expect(ids, containsAll(['photo', 'audio', 'mystery']));
      expect(ids.toSet(), hasLength(6));
      final first = SessionGenerator(Random(seed)).generate(candidates, {}, 1);
      expect(first.where((id) => id.startsWith('pio_migration_')), isEmpty);
    }
  });
  final pool = [
    for (var i = 0; i < 300; i++)
      Question({'id': 'q$i', 'kind': 'quiz', 'species_id': 'bird${i % 20}'}),
    Question({'id': 'a', 'kind': 'audio', 'species_id': 'bird0'}),
    Question({'id': 'p', 'kind': 'photo', 'species_id': 'bird1'}),
  ];
  test(
    'Name recall is included from chapter one without displacing photos',
    () {
      final withMystery = [
        ...pool,
        Question({'id': 'hidden', 'kind': 'mystery', 'species_id': 'bird21'}),
      ];
      for (var seed = 0; seed < 20; seed++) {
        final ids = SessionGenerator(Random(seed)).generate(withMystery, {}, 1);
        expect(ids, containsAll(['hidden', 'p']));
        expect(ids, isNot(contains('a')));
        expect(ids.toSet(), hasLength(6));
      }
    },
  );
  test(
    'Sparse audio and photos are not drowned out by hundreds of quizzes',
    () {
      for (var seed = 0; seed < 30; seed++) {
        final ids = SessionGenerator(Random(seed)).generate(pool, {}, 5);
        expect(ids, containsAll(['a', 'p']));
        expect(ids.toSet(), hasLength(6));
        expect(
          ids.map((id) => pool.firstWhere((q) => q.id == id).species).toSet(),
          hasLength(6),
        );
      }
    },
  );
  test(
    'First chapter stays visual/knowledge; unseen birds precede recent ones',
    () {
      final ids = SessionGenerator(
        Random(2),
      ).generate(pool, {'p|q2|q3|q4|q5|q6'}, 1);
      expect(ids, contains('p'));
      expect(ids, isNot(contains('a')));
      final otherBirds = ids
          .where((id) => id != 'p')
          .map((id) => pool.firstWhere((q) => q.id == id).species)
          .toSet();
      expect(
        otherBirds.intersection({'bird2', 'bird3', 'bird4', 'bird5', 'bird6'}),
        isEmpty,
      );
    },
  );
  test(
    'Small pools keep all available skills without repeating question IDs',
    () {
      final small = [pool[0], pool[1], pool[2], pool[300]];
      final ids = SessionGenerator(Random(3)).generate(small, {}, 2);
      expect(ids.toSet(), hasLength(4));
      expect(ids, contains('a'));
    },
  );
}
