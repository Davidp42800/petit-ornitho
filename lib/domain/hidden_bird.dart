import 'dart:math';

/// Accents remain on the answer; keyboard guesses accept the base letter.
String baseLetter(String value) {
  var result = value.toUpperCase();
  const accented = 'ÀÂÄÁÃÅÇÉÈÊËÍÌÎÏÓÒÔÖÕÚÙÛÜŸ';
  const plain = 'AAAAAACEEEEIIIIOOOOOUUUUY';
  for (var i = 0; i < accented.length; i++) {
    result = result.replaceAll(accented[i], plain[i]);
  }
  return result;
}

class HiddenBird {
  final String name;
  final Random random;
  final Set<String> guessed = {};
  int lettersHelped = 0;
  HiddenBird(this.name, {Random? random}) : random = random ?? Random();
  bool isLetter(String char) => RegExp(r'^[A-Z]$').hasMatch(baseLetter(char));
  bool visible(String char) =>
      !isLetter(char) || guessed.contains(baseLetter(char));
  bool get complete => name.split('').every(visible);
  bool guess(String letter) {
    final normalized = baseLetter(letter);
    if (complete || !isLetter(normalized) || !guessed.add(normalized)) {
      return false;
    }
    return baseLetter(name).contains(normalized);
  }

  String? pickHiddenLetter() {
    final hidden = <String, String>{};
    for (final char in name.split('')) {
      if (!visible(char)) {
        hidden.putIfAbsent(baseLetter(char), () => char.toUpperCase());
      }
    }
    if (hidden.isEmpty) return null;
    return hidden.values.elementAt(random.nextInt(hidden.length));
  }

  String? reveal([String? selected]) {
    final letter = selected ?? pickHiddenLetter();
    if (letter == null ||
        visible(letter) ||
        !baseLetter(name).contains(baseLetter(letter))) {
      return null;
    }
    lettersHelped++;
    guess(letter);
    return letter.toUpperCase();
  }
}

String normalizeBirdName(String value) => baseLetter(
  value.trim(),
).replaceAll('’', "'").replaceAll(RegExp(r'\s+'), ' ');

/// Only one edit is tolerated, including an adjacent letter transposition.
/// A unique match is required; exact names always take precedence.
int tolerantBirdChoice(String input, List<String> options) {
  final typed = normalizeBirdName(input);
  final exact = options.indexWhere((v) => normalizeBirdName(v) == typed);
  if (exact >= 0) return exact;
  if (typed.length < 5) return -1;
  final matches = <int>[];
  for (var i = 0; i < options.length; i++) {
    final name = normalizeBirdName(options[i]);
    if ((typed.length - name.length).abs() > 1) continue;
    final d = List.generate(
      typed.length + 1,
      (i) => List.generate(
        name.length + 1,
        (j) => i == 0
            ? j
            : j == 0
            ? i
            : 0,
      ),
    );
    for (var a = 1; a <= typed.length; a++) {
      for (var b = 1; b <= name.length; b++) {
        d[a][b] = min(
          min(d[a - 1][b] + 1, d[a][b - 1] + 1),
          d[a - 1][b - 1] + (typed[a - 1] == name[b - 1] ? 0 : 1),
        );
        if (a > 1 &&
            b > 1 &&
            typed[a - 1] == name[b - 2] &&
            typed[a - 2] == name[b - 1]) {
          d[a][b] = min(d[a][b], d[a - 2][b - 2] + 1);
        }
      }
    }
    if (d.last.last == 1) matches.add(i);
  }
  return matches.length == 1 ? matches.single : -1;
}

String birdSpellingExplanation(String typed, String correct) {
  final a = normalizeBirdName(typed), b = normalizeBirdName(correct);
  for (var i = 1; i < b.length; i++) {
    if (b[i] == b[i - 1] && b.replaceRange(i, i + 1, '') == a) {
      return 'Attention, « $correct » s’écrit avec deux ${b[i]} !';
    }
  }
  return 'La bonne orthographe est « $correct ». Observe bien les lettres !';
}
