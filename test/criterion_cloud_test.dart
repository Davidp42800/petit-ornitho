import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
// ignore: depend_on_referenced_packages
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:petit_ornitho/data/game_store.dart';
import 'package:petit_ornitho/domain/decisive_criterion.dart';

class ConnectedCriterionStore extends GameStore {
  final SupabaseClient remote;
  ConnectedCriterionStore(super.prefs, super.content, super.media, this.remote);
  @override
  String get identity => 'synthetic-account';
  @override
  SupabaseClient get client => remote;
}

void main() {
  test(
    'connected answers send version and phase; only server result is persisted',
    () async {
      SharedPreferences.setMockInitialValues({});
      final content =
          jsonDecode(File('assets/data/content.json').readAsStringSync())
              as Map<String, dynamic>;
      final q = Map<String, dynamic>.from(content['questions'][0])
        ..addAll({
          'format': 'decisive_criterion',
          'version': 3,
          'options': ['A', 'B'],
          'answer': 1,
          'justification': {
            'options': ['X', 'Y', 'Z'],
            'answer': 2,
          },
        });
      content['questions'] = [q];
      var progress = DecisiveCriterion.start(q);
      var requests = 0;
      bool fail = false;
      final remote = SupabaseClient(
        'https://example.supabase.co',
        'fixture',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((r) async {
          if (r.url.path.endsWith('/journey_questions')) {
            return http.Response(
              jsonEncode([q]),
              200,
              request: r,
              headers: {'content-type': 'application/json'},
            );
          }
          expect(r.url.path, endsWith('/answer_garden_criterion'));
          final body = jsonDecode(r.body);
          expect(body['p_version'], 3);
          expect(body['p_session'], 'test-session');
          expect(body['p_index'], 0);
          if (fail) {
            return http.Response('{"message":"temporary"}', 503, request: r);
          }
          progress = progress.choose(
            q,
            CriterionPhase.values.byName(body['p_phase']),
            body['p_choice'],
          );
          requests++;
          return http.Response(
            jsonEncode({
              'id': 'test-session',
              'ids': [q['id']],
              'index': 0,
              'level': 1,
              'hints': 1,
              'answers': [],
              'criterion': progress.toJson(),
              'score': progress.phase(q) == null ? 10 : 0,
              if (progress.phase(q) == null)
                'feedback': {
                  'correct': true,
                  'points': 10,
                  'choice': 1,
                  'answer': 1,
                },
            }),
            200,
            request: r,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(remote.dispose);
      final s = ConnectedCriterionStore(
        await SharedPreferences.getInstance(),
        content,
        [],
        remote,
      )..reload();
      s.state['active'] = {
        'id': 'test-session',
        'ids': [q['id']],
        'index': 0,
        'score': 0,
      };
      await s.fetchJourneyQuestions();
      await s.answerCriterion(CriterionPhase.identification, 1);
      s.reload();
      expect(s.active!['criterion']['identification'], [1]);
      expect(s.active!['score'], 0);
      final before = jsonEncode(s.state);
      fail = true;
      await expectLater(
        s.answerCriterion(CriterionPhase.justification, 2),
        throwsA(isA<PostgrestException>()),
      );
      expect(jsonEncode(s.state), before);
      fail = false;
      await s.answerCriterion(CriterionPhase.justification, 2);
      s.reload();
      expect(
        s.active!['score'],
        10,
      ); // Never recompute the server's reward locally.
      expect(s.attempts, isEmpty);
      expect(requests, 2);
    },
  );
}
