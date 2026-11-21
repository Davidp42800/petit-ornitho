import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:petit_ornitho/domain/game.dart';

void main() {
  final content = jsonDecode(
    File('assets/data/content.json').readAsStringSync(),
  );
  final pool = (content['questions'] as List)
      .map((x) => Question(Map<String, dynamic>.from(x)))
      .toList();
  test('500 successive sessions never repeat an ordered series', () {
    final history = <String>{};
    final gen = SessionGenerator(Random(42));
    for (var i = 0; i < 500; i++) {
      final ids = gen.generate(pool, history, 1);
      expect(ids.length, 6);
      expect(ids.toSet().length, 6);
      expect(history.add(ids.join('|')), isTrue);
    }
  });
  test('Hints reduce reward and errors never grant XP', () {
    expect(reward(true, 1), 15);
    expect(reward(true, 2), 10);
    expect(reward(true, 3), 5);
    expect(reward(false, 1), 0);
  });
  test('Every question has evidence, a valid answer and a known species', () {
    final catalog = jsonDecode(File('assets/data/species_catalog.json').readAsStringSync());
    final ids = (catalog['species'] as List).map((s) => s['id']).toSet();
    for (final q in pool) {
      expect(ids.contains(q.species), isTrue);
      expect(q.answer, inInclusiveRange(0, q.options.length - 1));
      expect(q.options.toSet().length, q.options.length);
      expect(Uri.parse(q.data['source']).scheme, 'https');
      expect(q.explanation, isNotEmpty);
    }
  });
}
