import 'dart:math';

/// Explicit SM-2 adaptation, not FSRS. Same rule as the database projection.
Map<String, dynamic> scheduleSkill(
  Map<String, dynamic>? previous,
  bool correct,
  bool assisted,
  DateTime now,
) {
  final s = Map<String, dynamic>.from(previous ?? {});
  final last = DateTime.tryParse(s['last_scheduled_at'] ?? '');
  final autonomous = correct && !assisted;
  s['seen'] = (s['seen'] as int? ?? 0) + 1;
  s['correct'] = (s['correct'] as int? ?? 0) + (correct ? 1 : 0);
  s['last_seen_at'] = now.toUtc().toIso8601String();
  if (autonomous && last != null && now.difference(last).inHours < 24) return s;
  final quality = autonomous ? 4 : 2;
  final ease = (s['ease'] as num? ?? 2.5).toDouble();
  final repetitions = autonomous ? (s['repetitions'] as int? ?? 0) + 1 : 0;
  final days = !autonomous || repetitions == 1
      ? 1
      : repetitions == 2
      ? 6
      : min(365, ((s['interval_days'] as num? ?? 1) * ease).ceil());
  return {
    ...s,
    'repetitions': repetitions,
    'interval_days': days,
    'ease': max(
      1.3,
      ease + 0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02),
    ),
    'due_at': now.add(Duration(days: days)).toUtc().toIso8601String(),
    'last_scheduled_at': now.toUtc().toIso8601String(),
    'algorithm': 'sm2-binary-v1',
  };
}

String newAttemptId() {
  final r = Random.secure();
  final b = List.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 15) | 64;
  b[8] = (b[8] & 63) | 128;
  final h = b.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

/// Curated confusions first, then verified genus/family/order. Unknown taxonomy
/// never creates a spurious match. Personal mistakes add bounded priority.
List<dynamic> plausibleChoices(
  dynamic target,
  List<dynamic> pool,
  Map<String, dynamic> rules,
  List<dynamic> attempts,
  Random rng, {
  String modality = 'visual',
  int count = 3,
}) {
  final taxonomy = rules['taxonomy'] as Map? ?? {};
  final t = taxonomy[target['id']] as Map? ?? {};
  final candidates = pool.where((s) => s['id'] != target['id']).toList()
    ..shuffle(rng);
  double weight(dynamic candidate) {
    final c = taxonomy[candidate['id']] as Map? ?? {};
    var score = 0.0;
    for (final pair in rules['confusions'] as List? ?? []) {
      if (pair['modality'] == modality &&
          {
            pair['species_a'],
            pair['species_b'],
          }.containsAll([target['id'], candidate['id']])) {
        score += 100 * (pair['weight'] as num).toDouble();
      }
    }
    if (t['genus'] != null && t['genus'] == c['genus']) score += 30;
    if (t['family'] != null && t['family'] == c['family']) score += 20;
    if (t['order'] != null && t['order'] == c['order']) score += 5;
    final errors = attempts
        .where(
          (a) =>
              a['modality'] == modality &&
              a['correct'] == false &&
              {
                a['target_species'],
                a['chosen_species'],
              }.containsAll([target['id'], candidate['id']]),
        )
        .length;
    return score + min(5, errors) * 40;
  }

  candidates.sort((a, b) => weight(b).compareTo(weight(a)));
  return candidates.take(count).toList();
}

/// Half the round for due birds, the rest for discovery; no duplicate species.
List<T> revisionRound<T>(
  List<T> pool,
  String Function(T) species,
  String modality,
  Map<String, dynamic> skills,
  Random rng,
  DateTime now,
  int size,
) {
  final shuffled = List<T>.of(pool)..shuffle(rng);
  final due = shuffled.where((item) {
    final d = DateTime.tryParse(
      skills['${species(item)}:$modality']?['due_at'] ?? '',
    );
    return d != null && !d.isAfter(now);
  }).toList();
  due.sort(
    (a, b) => (skills['${species(a)}:$modality']['due_at'] as String).compareTo(
      skills['${species(b)}:$modality']['due_at'] as String,
    ),
  );
  final result = <T>[];
  final seen = <String>{};
  for (final item in [...due.take((size / 2).ceil()), ...shuffled]) {
    if (seen.add(species(item))) result.add(item);
    if (result.length == size) break;
  }
  return result;
}

/// Least recently answered first, with in-session reservations (a shuffled bag).
/// Reservations prevent consecutive repeats even before a timed round is saved.
class PhotoRotation {
  final Map<String, int> _reserved = {};
  int _sequence = 0;
  dynamic pick(
    List<dynamic> photos,
    Map<String, dynamic> lastSeen,
    Random random,
  ) {
    final candidates = List<dynamic>.of(photos)..shuffle(random);
    candidates.sort((a, b) {
      final ar = _reserved[a['id']], br = _reserved[b['id']];
      if (ar != null && br != null) return ar.compareTo(br);
      if (ar != null) return 1;
      if (br != null) return -1;
      final at =
          DateTime.tryParse(lastSeen[a['id']] ?? '')?.microsecondsSinceEpoch ??
          0;
      final bt =
          DateTime.tryParse(lastSeen[b['id']] ?? '')?.microsecondsSinceEpoch ??
          0;
      return at.compareTo(bt);
    });
    final chosen = candidates.first;
    _reserved[chosen['id']] = _sequence++;
    return chosen;
  }
}
