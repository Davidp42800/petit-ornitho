import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:petit_ornitho/domain/decisive_criterion.dart';

void main() {
  Map<String, dynamic> question() => {
    'id': 'synthetic_pair',
    'version': 2,
    'format': 'decisive_criterion',
    'options': ['Oiseau A', 'Oiseau B'],
    'answer': 1,
    'justification': {
      'options': ['Critère A', 'Critère B', 'Critère C'],
      'answer': 2,
    },
  };
  const identification = CriterionPhase.identification;
  const justification = CriterionPhase.justification;
  test(
    'identification alone never certifies understanding; reload keeps step',
    () {
      final q = question();
      var s = DecisiveCriterion.start(q).choose(q, identification, 1);
      expect(s.autonomousSuccess(q), false);
      expect(s.phase(q), justification);
      s = DecisiveCriterion.restore(q, jsonDecode(jsonEncode(s.toJson())));
      expect(s.phase(q), justification);
      s = s.choose(q, justification, 2);
      expect(s.phase(q), isNull);
      expect(s.autonomousSuccess(q), true);
      expect(
        DecisiveCriterion.restore(q, s.toJson()).autonomousSuccess(q),
        true,
      );
    },
  );
  test('late and duplicate submissions cannot answer the other step', () {
    final q = question();
    final s = DecisiveCriterion.start(q).choose(q, identification, 1);
    expect(identical(s.choose(q, identification, 1), s), true);
    expect(() => s.choose(q, identification, 0), throwsStateError);
    expect(s.justificationChoices, isEmpty);
    final done = s.choose(q, justification, 2);
    expect(identical(done.choose(q, justification, 2), done), true);
    expect(() => done.choose(q, justification, 0), throwsStateError);
  });
  test('errors permit correction but preserve both first-answer results', () {
    final q = question();
    final s = DecisiveCriterion.start(q)
        .choose(q, identification, 0)
        .choose(q, identification, 1)
        .choose(q, justification, 2);
    expect(s.phase(q), isNull);
    expect(s.firstTryCorrect(q, identification), false);
    expect(s.firstTryCorrect(q, justification), true);
    expect(s.autonomousSuccess(q), false);
    final j = DecisiveCriterion.start(q)
        .choose(q, identification, 1)
        .choose(q, justification, 0)
        .choose(q, justification, 2);
    expect(j.firstTryCorrect(q, identification), true);
    expect(j.firstTryCorrect(q, justification), false);
    expect(j.autonomousSuccess(q), false);
  });
  test('assistance is durable and never turns into autonomous mastery', () {
    final q = question();
    final s = DecisiveCriterion.start(
      q,
    ).choose(q, identification, 1).withAssistance().choose(q, justification, 2);
    expect(s.autonomousSuccess(q), false);
    expect(DecisiveCriterion.restore(q, s.toJson()).assisted, true);
  });
  test(
    'rejects incompatible version, premature step and malformed history',
    () {
      final q = question();
      final s = DecisiveCriterion.start(q);
      expect(() => s.choose(q, justification, 2), throwsStateError);
      expect(() => s.choose(q, identification, 3), throwsArgumentError);
      expect(() => s.phase({...q, 'version': 3}), throwsStateError);
      for (final invalid in [
        {...s.toJson(), 'version': 3},
        {
          ...s.toJson(),
          'justification': [2],
        },
        {
          ...s.toJson(),
          'identification': [0, 0],
        },
        {
          ...s.toJson(),
          'identification': [1, 0],
        },
        {
          ...s.toJson(),
          'identification': ['1'],
        },
      ]) {
        expect(
          () => DecisiveCriterion.restore(q, invalid),
          throwsFormatException,
        );
      }
    },
  );
  test('state cannot be mutated through caller-owned lists', () {
    final q = question();
    final s = DecisiveCriterion.start(q).choose(q, identification, 1);
    expect(() => s.identificationChoices.add(0), throwsUnsupportedError);
    (s.toJson()['identification'] as List).clear();
    expect(s.identificationChoices, [1]);
  });
}
