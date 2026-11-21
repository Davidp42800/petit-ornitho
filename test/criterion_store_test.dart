import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:petit_ornitho/data/game_store.dart';
import 'package:petit_ornitho/domain/decisive_criterion.dart';

class GuestCriterionStore extends GameStore {
  GuestCriterionStore(
    SharedPreferences prefs,
    Map<String, dynamic> content, {
    Future<bool> Function(String, String)? persist,
  }) : super(prefs, content, [], persist: persist, knowledgeCatalog: {});
  @override
  String get identity => 'guest';
}

void main() {
  const bird = CriterionPhase.identification;
  const reason = CriterionPhase.justification;
  Future<GuestCriterionStore> fixture({
    Future<bool> Function(String, String)? persist,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final content =
        jsonDecode(File('assets/data/content.json').readAsStringSync())
            as Map<String, dynamic>;
    final q = Map<String, dynamic>.from(content['questions'].first);
    q.addAll({
      'id': 'synthetic_criterion',
      'kind': 'quiz',
      'format': 'decisive_criterion',
      'options': ['A', 'B'],
      'answer': 1,
      'justification': {
        'options': ['X', 'Y', 'Z'],
        'answer': 2,
      },
    });
    content['questions'] = [q, ...content['questions']];
    final s = GuestCriterionStore(
      await SharedPreferences.getInstance(),
      content,
      persist: persist,
    )..reload();
    s.state['active'] = {
      'id': 'synthetic_session',
      'ids': [q['id'], content['questions'][1]['id']],
      'index': 0,
      'hints': 1,
      'level': 1,
      'score': 0,
      'answers': [],
    };
    await s.save();
    return s;
  }

  test(
    'two answers persist, award once and clear state at next question',
    () async {
      final s = await fixture();
      await expectLater(s.answer(1), throwsStateError);
      await s.answerCriterion(bird, 1);
      expect(s.active!['score'], 0);
      expect(s.active!['feedback'], isNull);
      expect(s.attempts, isEmpty);
      await s.next();
      expect(s.active!['index'], 0);
      s.reload();
      expect(s.active!['criterion']['identification'], [1]);
      await s.answerCriterion(reason, 2);
      await s.answerCriterion(reason, 2);
      expect(s.active!['score'], 15);
      expect(s.attempts.length, 1);
      expect(s.attempts.single['justification_correct'], true);
      await s.next();
      expect(s.active!['criterion'], isNull);
    },
  );
  test(
    'one-choice practice cannot create comparative mastery evidence',
    () async {
      final s = await fixture();
      final before = jsonEncode(s.state);
      final q = s.current;
      await expectLater(
        s.recordPractice(q, q.answer, 'synthetic_practice', 1000),
        throwsStateError,
      );
      expect(jsonEncode(s.state), before);
      expect(s.practiceQuestions.any((item) => item.id == q.id), false);
      expect(s.learningRound().any((item) => item.id == q.id), false);
      s.knowledgeCatalog['questions'] = [q.data];
      expect(s.learningRound().any((item) => item.id == q.id), false);
      // The full two-step journey remains available.
      await s.answerCriterion(bird, q.answer);
      expect(s.attempts, isEmpty);
      await s.answerCriterion(reason, 2);
      expect(s.attempts.single['justification_correct'], true);
    },
  );
  test(
    'error correction is recorded without converting it into first-try success',
    () async {
      final s = await fixture();
      await s.answerCriterion(bird, 1);
      await s.answerCriterion(reason, 0);
      s.reload();
      await s.answerCriterion(reason, 2);
      expect(s.active!['score'], 0);
      expect(s.attempts.single['identification_correct'], true);
      expect(s.attempts.single['justification_correct'], false);
      expect(s.attempts.single['correct'], false);
    },
  );
  test('failed final save retries atomically without double reward', () async {
    bool fail = false;
    final s = await fixture(
      persist: (k, v) async => fail
          ? false
          : (await SharedPreferences.getInstance()).setString(k, v),
    );
    await s.answerCriterion(bird, 1);
    final before = jsonEncode(s.state);
    fail = true;
    await expectLater(s.answerCriterion(reason, 2), throwsStateError);
    expect(jsonEncode(s.state), before);
    fail = false;
    await s.answerCriterion(reason, 2);
    s.reload();
    await s.answerCriterion(reason, 2);
    expect(s.active!['score'], 15);
    expect(s.attempts.length, 1);
  });
  test(
    'help between answers reduces reward and remains assisted after reload',
    () async {
      final s = await fixture();
      await s.answerCriterion(bird, 1);
      await s.registerGuideHint();
      s.reload();
      await s.answerCriterion(reason, 2);
      expect(s.attempts.single['assisted'], true);
      expect(s.active!['score'], 10);
    },
  );
}
