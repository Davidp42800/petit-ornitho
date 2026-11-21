/// Evidence-based mastery, separate from prototype ranks and XP.
/// Callers must supply server-verified answers and currently approved references.
/// This evaluator never makes a raw client answer authoritative.
enum BirdSkill { visual, audio, knowledge }

class MasteryEvidence {
  final String id, speciesId, referenceId;
  final BirdSkill skill;
  final DateTime answeredAt;
  final bool correct, assisted;
  const MasteryEvidence({
    required this.id,
    required this.speciesId,
    required this.referenceId,
    required this.skill,
    required this.answeredAt,
    required this.correct,
    required this.assisted,
  });
}

class MasteryAssessment {
  final bool mastered;
  final int successes, distinctReferences, sessions, recentCorrect, recentTotal;
  final bool spacedReview, latestCorrect;
  final List<String> missing;
  const MasteryAssessment({
    required this.mastered,
    required this.successes,
    required this.distinctReferences,
    required this.sessions,
    required this.recentCorrect,
    required this.recentTotal,
    required this.spacedReview,
    required this.latestCorrect,
    required this.missing,
  });
}

/// v1: four unaided successes, >=80% on the latest five unaided answers,
/// three separate practice sessions, and a successful review after >=24 hours.
/// A session is inferred by a 20-minute gap, never by a client-chosen ID.
/// Knowledge references are fact IDs, so rewordings do not simulate breadth.
MasteryAssessment assessMastery({
  required String speciesId,
  required BirdSkill skill,
  required Iterable<MasteryEvidence> evidence,
  required Set<String> approvedReferences,
  required DateTime now,
}) {
  final unique = <String, MasteryEvidence>{};
  final conflicting = <String>{};
  for (final e in evidence) {
    if (e.id.isEmpty ||
        e.speciesId != speciesId ||
        e.skill != skill ||
        e.answeredAt.isAfter(now) ||
        !approvedReferences.contains(e.referenceId)) {
      continue;
    }
    final old = unique[e.id];
    if (old != null &&
        (old.referenceId != e.referenceId ||
            old.correct != e.correct ||
            old.assisted != e.assisted ||
            old.answeredAt != e.answeredAt)) {
      conflicting.add(e.id);
    }
    unique.putIfAbsent(e.id, () => e);
  }
  final rows =
      unique.values
          .where((e) => !conflicting.contains(e.id) && !e.assisted)
          .toList()
        ..sort((a, b) {
          final c = a.answeredAt.compareTo(b.answeredAt);
          return c == 0 ? a.id.compareTo(b.id) : c;
        });
  final correct = rows.where((e) => e.correct).toList();
  final references = correct.map((e) => e.referenceId).toSet().length;
  // Count only sessions containing an unaided success, including errors in gaps.
  final successfulSessions = <int>{};
  DateTime? previous;
  var session = 0;
  for (final e in rows) {
    if (previous == null ||
        e.answeredAt.difference(previous) >= const Duration(minutes: 20)) {
      session++;
    }
    if (e.correct) successfulSessions.add(session);
    previous = e.answeredAt;
  }
  final recent = rows.skip(rows.length > 5 ? rows.length - 5 : 0).toList();
  final recentCorrect = recent.where((e) => e.correct).length;
  final spaced =
      correct.length >= 2 &&
      correct.last.answeredAt.difference(correct.first.answeredAt) >=
          const Duration(hours: 24);
  final latestCorrect = rows.isNotEmpty && rows.last.correct;
  final neededReferences = skill == BirdSkill.audio ? 2 : 3;
  final missing = <String>[
    if (approvedReferences.length < neededReferences) 'content_incomplete',
    if (correct.length < 4) 'four_unaided_successes',
    if (references < neededReferences) 'varied_references',
    if (successfulSessions.length < 3) 'three_sessions',
    if (!spaced) 'review_after_24h',
    if (recent.length < 4 || recentCorrect * 5 < recent.length * 4)
      'recent_accuracy_80',
    if (!latestCorrect) 'latest_answer_correct',
  ];
  return MasteryAssessment(
    mastered: missing.isEmpty,
    successes: correct.length,
    distinctReferences: references,
    sessions: successfulSessions.length,
    recentCorrect: recentCorrect,
    recentTotal: recent.length,
    spacedReview: spaced,
    latestCorrect: latestCorrect,
    missing: List.unmodifiable(missing),
  );
}

/// Readiness for the Expert title across the complete authorised catalogue.
/// This is not a certificate: only server-issued, server-corrected missions
/// may supply the assessments used to award a title.
class ExpertReadiness {
  final int requiredSkills, masteredSkills, contentGaps;
  final bool eligible;
  const ExpertReadiness({
    required this.requiredSkills,
    required this.masteredSkills,
    required this.contentGaps,
    required this.eligible,
  });
}

ExpertReadiness assessExpertReadiness({
  required Set<String> requiredSpecies,
  required Map<String, Map<BirdSkill, MasteryAssessment>> assessments,
}) {
  var mastered = 0;
  var contentGaps = 0;
  for (final species in requiredSpecies) {
    for (final skill in BirdSkill.values) {
      final assessment = assessments[species]?[skill];
      if (assessment?.mastered == true) mastered++;
      if (assessment?.missing.contains('content_incomplete') == true) {
        contentGaps++;
      }
    }
  }
  final required = requiredSpecies.length * BirdSkill.values.length;
  return ExpertReadiness(
    requiredSkills: required,
    masteredSkills: mastered,
    contentGaps: contentGaps,
    eligible: required > 0 && mastered == required && contentGaps == 0,
  );
}
