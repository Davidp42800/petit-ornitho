import 'package:flutter_test/flutter_test.dart';
import 'package:petit_ornitho/domain/mastery.dart';

void main() {
  final start = DateTime.utc(2026, 10, 3);
  final now = start.add(const Duration(days: 3));
  MasteryEvidence e(
    int id,
    int minutes, {
    String? ref,
    bool correct = true,
    bool assisted = false,
    BirdSkill skill = BirdSkill.visual,
  }) => MasteryEvidence(
    id: 'a$id',
    speciesId: 'robin',
    referenceId: ref ?? 'p${id % 3}',
    skill: skill,
    answeredAt: start.add(Duration(minutes: minutes)),
    correct: correct,
    assisted: assisted,
  );
  MasteryAssessment check(
    List<MasteryEvidence> rows, {
    Set<String>? refs,
    BirdSkill skill = BirdSkill.visual,
  }) => assessMastery(
    speciesId: 'robin',
    skill: skill,
    evidence: rows,
    approvedReferences: refs ?? {'p0', 'p1', 'p2'},
    now: now,
  );
  final valid = [e(0, 0), e(1, 1), e(2, 30), e(3, 1440)];
  test('several references and spaced sessions establish mastery', () {
    expect(check(valid).mastered, true);
  });
  test('five minutes and huge XP cannot establish mastery', () {
    final r = check(List.generate(50, (i) => e(i, i ~/ 10)));
    expect(r.mastered, false);
    expect(r.missing, containsAll(['three_sessions', 'review_after_24h']));
  });
  test('repeating one photo cannot establish mastery', () {
    expect(
      check([
        e(0, 0, ref: 'p0'),
        e(1, 30, ref: 'p0'),
        e(2, 60, ref: 'p0'),
        e(3, 1500, ref: 'p0'),
      ]).missing,
      contains('varied_references'),
    );
  });
  test('assisted answers and duplicate attempts add no proof', () {
    expect(
      check([
        ...valid.map((x) => e(int.parse(x.id.substring(1)) + 100, 0, assisted: true)),
        ...List.filled(10, valid.first),
      ]).successes,
      1,
    );
  });
  test('unpublished references and future timestamps do not count', () {
    expect(
      check([...valid, e(8, 99999), e(9, 1500, ref: 'unapproved')]).successes,
      4,
    );
    expect(check(valid, refs: {'p0'}).missing, contains('content_incomplete'));
  });
  test('last error requires another successful review', () {
    expect(
      check([...valid, e(4, 1600, correct: false)]).missing,
      contains('latest_answer_correct'),
    );
  });
  test('old successes cannot hide current low accuracy', () {
    expect(
      check([
        ...valid,
        e(4, 1600, correct: false),
        e(5, 1601, correct: false),
        e(6, 1602),
      ]).missing,
      contains('recent_accuracy_80'),
    );
  });
  test('contradictory replay is discarded', () {
    expect(check([...valid, e(0, 0, correct: false)]).successes, 3);
  });
  test('facts rather than wording define knowledge variety', () {
    expect(
      check(
        [
          e(0, 0, ref: 'fact1', skill: BirdSkill.knowledge),
          e(1, 30, ref: 'fact1', skill: BirdSkill.knowledge),
          e(2, 60, ref: 'fact1', skill: BirdSkill.knowledge),
          e(3, 1440, ref: 'fact1', skill: BirdSkill.knowledge),
        ],
        refs: {'fact1', 'fact2', 'fact3'},
        skill: BirdSkill.knowledge,
      ).mastered,
      false,
    );
  });
  test('audio requires two independently approved recordings', () {
    expect(
      check(
        [
          e(0, 0, ref: 's1', skill: BirdSkill.audio),
          e(1, 30, ref: 's2', skill: BirdSkill.audio),
          e(2, 60, ref: 's1', skill: BirdSkill.audio),
          e(3, 1440, ref: 's2', skill: BirdSkill.audio),
        ],
        refs: {'s1', 's2'},
        skill: BirdSkill.audio,
      ).mastered,
      true,
    );
  });
}
