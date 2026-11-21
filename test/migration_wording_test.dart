import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:petit_ornitho/domain/game.dart';

void main() {
  test(
    'Migration wording improves all legacy snapshots without changing evidence',
    () {
      final rows =
          jsonDecode(
                File('assets/data/knowledge_catalog.json').readAsStringSync(),
              )['questions']
              as List;
      final migration = rows.where(
        (q) => (q['prompt'] as String).startsWith(
          'Pio prépare le carnet de voyage : ',
        ),
      );
      expect(migration.length, 287);
      final starts = <String>{};
      for (final raw in migration) {
        final data = Map<String, dynamic>.from(raw);
        final before = jsonEncode(data);
        final q = Question(data);
        expect(q.prompt, isNot(contains('Pio prépare le carnet de voyage')));
        expect(q.prompt.endsWith('?'), true);
        expect(
          q.prompt,
          contains(
            (raw['prompt'] as String)
                .split(' : ')[1]
                .split('. Quel portrait')[0],
          ),
        );
        expect(jsonEncode(data), before);
        expect(q.prompt, Question(Map<String, dynamic>.from(raw)).prompt);
        starts.add(q.prompt.split(':').first);
      }
      expect(starts.length, greaterThan(5));
    },
  );
  test('Unrelated prompts remain unchanged', () {
    expect(
      Question({'prompt': 'Qui chante ?', 'id': 'audio_1'}).prompt,
      'Qui chante ?',
    );
  });
}
