import 'dart:math';
import 'mystery_voice.dart';

class Question {
  final Map<String, dynamic> data;
  Question(this.data);
  String get id => data['id'] as String;
  String get kind => data['kind'] as String;
  String get species => data['species_id'] as String;
  List<String> get options => List<String>.from(data['options']);
  int get answer => data['answer'] as int;
  String get prompt {
    final original = data['prompt'] as String;
    const nestPrefix = 'Mission nid : ';
    const nestSuffix =
        '. Quel emplacement de ponte est indiqué dans sa fiche ?';
    if (original.startsWith(nestPrefix) && original.endsWith(nestSuffix)) {
      final bird = original.substring(
        nestPrefix.length,
        original.length - nestSuffix.length,
      );
      return '$bird : où pond-il ses œufs ?';
    }
    // Presentation-only repair also applies to saved question snapshots.
    // Answers, source facts, versions and mastery evidence remain unchanged.
    const prefix = 'Pio prépare le carnet de voyage : ';
    const suffix = '. Quel portrait correspond à ses déplacements ?';
    if (!original.startsWith(prefix) || !original.endsWith(suffix)) {
      return original.replaceAll('Pio', 'Pépi');
    }
    final bird = original.substring(
      prefix.length,
      original.length - suffix.length,
    );
    final variants = [
      '$bird : rester près de chez soi ou partir loin ?',
      'Au fil des saisons, comment se déplace cet oiseau : $bird ?',
      '$bird : quel voyage lui ressemble ?',
      'Un oiseau, plusieurs saisons : où va $bird ?',
      '$bird : quelle proposition décrit ses déplacements ?',
    ];
    final index = id.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
    return variants[index % variants.length];
  }

  String get explanation =>
      (data['explanation'] as String).replaceAll('Pio', 'Pépi');
  String get asset => data['asset'] as String;
  bool get isMigration =>
      data['source_locator'] == '/eigenschaften/zugverhalten' ||
      id.startsWith('pio_migration_');
  bool get isBeginnerSound =>
      kind == 'audio' &&
      const {
            'blackbird': 'song',
            'ch_3020': 'song',
            'ch_3681': 'call',
          }[species] !=
          null &&
      data['recording']?['type'] ==
          const {
            'blackbird': 'song',
            'ch_3020': 'song',
            'ch_3681': 'call',
          }[species];
  List<String> get clues => List<String>.from(data['clues'] ?? const <String>[])
      .map((text) => (mysteryVoices[text] ?? text)
          .replaceAll('Pio', 'Pépi')
          .replaceAll('anfractuosités', 'creux')
          .replaceAll('Anfractuosités', 'Creux'))
      .toList();
}

class SessionGenerator {
  final Random random;
  SessionGenerator([Random? random]) : random = random ?? Random();
  List<String> generate(List<Question> pool, Set<String> history, int level) {
    final eligible = pool
        .where(
          (q) => level == 1
              ? !q.isMigration &&
                    (q.kind == 'photo' ||
                        q.kind == 'quiz' ||
                        q.kind == 'mystery' ||
                        q.isBeginnerSound)
              : true,
        )
        .toList();
    if (eligible.length < 4) {
      throw StateError('Pas assez de défis pour cette balade.');
    }
    for (var attempt = 0; attempt < 2000; attempt++) {
      eligible.shuffle(random);
      final lastQuestion = <String, int>{};
      final lastBird = <String, int>{};
      final byId = {for (final q in eligible) q.id: q};
      var order = 0;
      for (final session in history) {
        for (final id in session.split('|')) {
          lastQuestion[id] = order;
          final bird = byId[id]?.species;
          if (bird != null) lastBird[bird] = order;
        }
        order++;
      }
      eligible.sort((a, b) {
        final birdOrder = (lastBird[a.species] ?? -1).compareTo(
          lastBird[b.species] ?? -1,
        );
        return birdOrder != 0
            ? birdOrder
            : (lastQuestion[a.id] ?? -1).compareTo(lastQuestion[b.id] ?? -1);
      });
      final selected = <Question>[];
      final birds = <String>{};
      void pick(bool Function(Question) accepts) {
        final candidates = eligible
            .where((q) => accepts(q) && !selected.contains(q))
            .toList();
        if (candidates.isEmpty) return;
        // Do not let the large migration catalogue fill the other game slots.
        // Keep a fallback for small pools so a valid series never gets stuck.
        final varied = selected.any((q) => q.isMigration)
            ? candidates.where((q) => !q.isMigration).toList()
            : candidates;
        final choices = varied.isEmpty ? candidates : varied;
        final q =
            choices.where((q) => !birds.contains(q.species)).firstOrNull ??
            choices.first;
        selected.add(q);
        birds.add(q.species);
      }

      // Reserve room for each available skill before filling the remaining slots.
      pick((q) => q.kind == 'audio');
      pick((q) => q.kind == 'photo');
      pick((q) => q.kind != 'photo' && q.kind != 'audio');
      pick((q) => q.kind == 'mystery' || q.isBeginnerSound);
      while (selected.length < min(6, eligible.length)) {
        pick((q) => true);
      }
      selected.shuffle(random);
      final chosen = selected.map((q) => q.id).toList();
      if (!history.contains(chosen.join('|'))) return chosen;
    }
    throw StateError('Toutes les séries disponibles ont été explorées.');
  }
}

int reward(bool correct, int hints) =>
    correct ? max(5, 15 - (hints - 1) * 5) : 0;
