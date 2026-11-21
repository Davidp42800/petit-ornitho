import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:petit_ornitho/domain/learning.dart';

void main() {
  test('SM2 separates guided success, daily repetition and spaced recall', () {
    final day = DateTime.utc(2026, 10, 3);
    var s = scheduleSkill(null, true, false, day);
    expect(s['interval_days'], 1);
    s = scheduleSkill(s, true, false, day.add(const Duration(minutes: 2)));
    expect(s['repetitions'], 1);
    s = scheduleSkill(s, true, false, day.add(const Duration(days: 1)));
    expect(s['interval_days'], 6);
    s = scheduleSkill(s, true, true, day.add(const Duration(days: 7)));
    expect(s['repetitions'], 0);
    expect(s['interval_days'], 1);
    expect(s['seen'], 4);
    expect(s['correct'], 4);
  });
  test(
    'Curated gull and duck confusions beat distant species, without duplicates',
    () {
      final rules = jsonDecode(
        File('assets/data/learning_rules.json').readAsStringSync(),
      );
      final pool =
          jsonDecode(
                File('assets/data/photo_catalog.json').readAsStringSync(),
              )['species']
              as List;
      for (final pair in [('ch_2550', 'ch_2563'), ('ch_720', 'ch_820')]) {
        final target = pool.firstWhere((b) => b['id'] == pair.$1);
        final choices = plausibleChoices(target, pool, rules, [], Random(3));
        expect(choices.first['id'], pair.$2);
        expect(choices.map((s) => s['id']).toSet().length, 3);
        expect(choices.any((s) => s['id'] == pair.$1), false);
      }
    },
  );
  test(
    'Due visual birds are prioritised without treating audio as visual mastery',
    () {
      final now = DateTime.utc(2026, 10, 3);
      final result = revisionRound(
        ['a', 'b', 'c', 'd', 'e'],
        (s) => s,
        'visual',
        {
          'e:visual': {'due_at': '2026-10-01T00:00:00Z'},
          'b:audio': {'due_at': '2026-09-01T00:00:00Z'},
        },
        Random(4),
        now,
        4,
      );
      expect(result.first, 'e');
      expect(result.toSet().length, 4);
    },
  );
  test(
    'Photo rotation shows all five before repeating, including across sessions',
    () {
      final photos = List.generate(5, (i) => {'id': 'p$i'});
      final bag = PhotoRotation();
      final rng = Random(7);
      final first = List.generate(5, (_) => bag.pick(photos, {}, rng)['id']);
      final second = List.generate(5, (_) => bag.pick(photos, {}, rng)['id']);
      expect(first.toSet().length, 5);
      expect(second.toSet().length, 5);
      expect(second.first, isNot(first.last));
      final resumed = PhotoRotation();
      final history = {
        for (var i = 0; i < 4; i++)
          'p$i': DateTime.utc(2026, 10, 3, i).toIso8601String(),
      };
      expect(resumed.pick(photos, history, Random(1))['id'], 'p4');
      expect(resumed.pick(photos, history, Random(1))['id'], 'p0');
    },
  );
}
