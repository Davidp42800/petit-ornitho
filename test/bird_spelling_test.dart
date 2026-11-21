import 'package:flutter_test/flutter_test.dart';
import 'package:petit_ornitho/domain/hidden_bird.dart';

void main() {
  const names = ['Sittelle torchepot', 'Merle noir', 'Mésange bleue'];
  test(
    'Small unique typos accepted; ambiguity and other birds stay distinct',
    () {
      expect(tolerantBirdChoice('sitelle torchepot', names), 0);
      expect(tolerantBirdChoice('Sittelle trochepot', names), 0);
      expect(tolerantBirdChoice('mesange BLEUE', names), 2);
      expect(tolerantBirdChoice('merle noir', names), 1);
      expect(tolerantBirdChoice('oiseau', names), -1);
      expect(
        tolerantBirdChoice('merle soir', ['Merle noir', 'Merle loir']),
        -1,
      );
      expect(
        birdSpellingExplanation('sitelle torchepot', names[0]),
        contains('deux T'),
      );
    },
  );
}
