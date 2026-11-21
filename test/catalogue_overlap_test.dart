import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:petit_ornitho/data/game_store.dart';

void main() {
  test(
    'overlapping catalogues preserve unique questions and latest version',
    () {
      final base =
          jsonDecode(
                File('assets/data/content.json').readAsStringSync(),
              )['questions']
              as List;
      final journey =
          jsonDecode(
                File('assets/data/journey_questions.json').readAsStringSync(),
              )
              as List;
      final ids = {...base.map((q) => q['id']), ...journey.map((q) => q['id'])};
      final merged = GameStore.mergeQuestionCatalogues(base, journey);
      expect(merged.map((q) => q['id']), unorderedEquals(ids));
      final next = {'id': 'test', 'version': 2};
      expect(
        GameStore.mergeQuestionCatalogues(
          [
            {'id': 'test'},
          ],
          [next],
        ),
        [next],
      );
      expect(
        GameStore.mergeQuestionCatalogues(
          [next],
          [
            {'id': 'test'},
          ],
        ),
        [next],
      );
    },
  );
}
