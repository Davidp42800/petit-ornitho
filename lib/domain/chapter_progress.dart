/// Chapter access is a learning milestone, separate from Expert certification.
class ChapterProgress {
  static const policies = {
    1: {
      'sessions': 3,
      'correct': 12,
      'species': 6,
      'visual': 4,
      'knowledge': 4,
      'audio': 0,
    },
    2: {
      'sessions': 4,
      'correct': 18,
      'species': 8,
      'visual': 6,
      'knowledge': 6,
      'audio': 4,
    },
    3: {
      'sessions': 5,
      'correct': 24,
      'species': 12,
      'visual': 8,
      'knowledge': 8,
      'audio': 6,
    },
    4: {
      'sessions': 6,
      'correct': 30,
      'species': 16,
      'visual': 10,
      'knowledge': 10,
      'audio': 8,
    },
  };
  final Map<String, int> counts, required;
  ChapterProgress(this.counts, this.required);
  bool get ready =>
      required.isNotEmpty &&
      required.entries.every((e) => (counts[e.key] ?? 0) >= e.value);
  Map<String, dynamic> toJson() => {
    'counts': counts,
    'required': required,
    'ready': ready,
  };
  factory ChapterProgress.fromJson(Map data) => ChapterProgress(
    Map<String, int>.from(data['counts'] ?? {}),
    Map<String, int>.from(data['required'] ?? {}),
  );

  factory ChapterProgress.evaluate(
    int stage,
    List<dynamic> attempts,
    List<dynamic> sessions,
  ) {
    final completed = {
      for (final s in sessions)
        if (s['stage'] == stage) s['id']: s,
    };
    final seen = <String>{};
    final eligible = attempts
        .where(
          (a) =>
              a['stage'] == stage &&
              a['protocol'] == 2 &&
              completed.containsKey(a['session_id']) &&
              a['id'] is String &&
              seen.add(a['id']),
        )
        .toList();
    final successes = eligible
        .where((a) => a['correct'] == true && a['assisted'] != true)
        .toList();
    var passed = 0;
    for (final session in completed.values) {
      final answers = eligible
          .where((a) => a['session_id'] == session['id'])
          .toList();
      final autonomous = answers
          .where((a) => a['correct'] == true && a['assisted'] != true)
          .length;
      if (answers.length >= 4 &&
          answers.length == session['total'] &&
          autonomous * 5 >= answers.length * 4) {
        passed++;
      }
    }
    int refs(String modality) => successes
        .where((a) => a['modality'] == modality && a['reference'] != null)
        .map((a) => '${a['target_species']}:${a['reference']}')
        .toSet()
        .length;
    return ChapterProgress({
      'sessions': passed,
      'correct': successes.length,
      'species': successes.map((a) => a['target_species']).toSet().length,
      'visual': refs('visual'),
      'knowledge': refs('knowledge'),
      'audio': refs('audio'),
    }, policies[stage] ?? {});
  }
}
