import 'package:flutter_test/flutter_test.dart';
import 'package:petit_ornitho/domain/mastery.dart';

void main() {
  const mastered = MasteryAssessment(
    mastered: true,
    successes: 4,
    distinctReferences: 3,
    sessions: 3,
    recentCorrect: 4,
    recentTotal: 4,
    spacedReview: true,
    latestCorrect: true,
    missing: [],
  );
  Map<BirdSkill, MasteryAssessment> complete() => {
    for (final skill in BirdSkill.values) skill: mastered,
  };

  test('empty catalogue never grants Expert', () {
    expect(
      assessExpertReadiness(requiredSpecies: {}, assessments: {}).eligible,
      false,
    );
  });
  test('all three skills for every required species are necessary', () {
    final assessments = {'robin': complete(), 'blackbird': complete()};
    expect(
      assessExpertReadiness(
        requiredSpecies: {'robin', 'blackbird'},
        assessments: assessments,
      ).eligible,
      true,
    );
    assessments['blackbird']!.remove(BirdSkill.audio);
    final result = assessExpertReadiness(
      requiredSpecies: {'robin', 'blackbird'},
      assessments: assessments,
    );
    expect(result.eligible, false);
    expect(result.masteredSkills, 5);
    expect(result.requiredSkills, 6);
  });
  test(
    'unavailable species remain required, unrelated species do not count',
    () {
      final result = assessExpertReadiness(
        requiredSpecies: {'robin', 'blackbird'},
        assessments: {'robin': complete(), 'unrelated': complete()},
      );
      expect(result.eligible, false);
      expect(result.masteredSkills, 3);
    },
  );
  test('missing content cannot silently remove an audio requirement', () {
    final skills = complete();
    skills[BirdSkill.audio] = const MasteryAssessment(
      mastered: false,
      successes: 0,
      distinctReferences: 0,
      sessions: 0,
      recentCorrect: 0,
      recentTotal: 0,
      spacedReview: false,
      latestCorrect: false,
      missing: ['content_incomplete'],
    );
    final result = assessExpertReadiness(
      requiredSpecies: {'robin'},
      assessments: {'robin': skills},
    );
    expect(result.contentGaps, 1);
    expect(result.eligible, false);
  });
}
