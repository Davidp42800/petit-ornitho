import 'package:flutter_test/flutter_test.dart';
import 'package:petit_ornitho/domain/practice_replay.dart';

void main() {
  test(
    'Le rejeu évite le premier et le dernier oiseaux et conserve le tirage',
    () {
      for (final initial in [
        ['a', 'b', 'c'],
        ['b', 'a', 'c'],
        ['c', 'b', 'a'],
        ['a', 'b'],
        ['b', 'a'],
        ['a'],
        <String>[],
      ]) {
        final deck = [...initial];
        varyReplayOpening(deck, (item) => item, 'a', 'b');
        expect(deck, unorderedEquals(initial));
        if (initial.length >= 3) expect(deck.first, 'c');
        if (initial.length == 2) expect(deck.first, 'a');
      }
    },
  );
}
