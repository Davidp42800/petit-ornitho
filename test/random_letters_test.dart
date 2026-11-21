import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:petit_ornitho/domain/hidden_bird.dart';

void main() {
  test('Letters vary, never repeat and keep the animated selection', () {
    final first = <String>{};
    for (var seed = 0; seed < 30; seed++) {
      final puzzle = HiddenBird('Mésange bleue', random: Random(seed));
      final revealed = <String>{};
      while (!puzzle.complete) {
        final letter = puzzle.pickHiddenLetter()!;
        if (revealed.isEmpty) first.add(letter);
        expect(puzzle.visible(letter), false);
        expect(puzzle.reveal(letter), letter);
        expect(puzzle.visible(letter), true);
        expect(revealed.add(baseLetter(letter)), true);
      }
      expect(puzzle.reveal(), null);
      expect(puzzle.lettersHelped, revealed.length);
    }
    expect(first.length, greaterThan(3));
  });
}
