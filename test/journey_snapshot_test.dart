import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
// ignore: depend_on_referenced_packages
import 'package:http/testing.dart';
import 'package:petit_ornitho/data/game_store.dart';

class SnapshotStore extends GameStore {
  String owner = 'fixture-owner';
  final SupabaseClient remote;
  SnapshotStore(
    SharedPreferences prefs,
    Map<String, dynamic> content,
    this.remote,
  ) : super(prefs, content, []);
  @override
  String get identity => owner;
  @override
  SupabaseClient get client => remote;
}

void main() {
  test(
    'saved version survives reload and never replaces the catalogue',
    () async {
      SharedPreferences.setMockInitialValues({});
      final q = {
        'id': 'same-id',
        'version': 9,
        'kind': 'quiz',
        'species_id': 'ch_1130',
        'prompt': 'Current catalogue',
        'options': ['A', 'B'],
        'answer': 0,
      };
      final saved = {
        ...q,
        'version': 2,
        'prompt': 'Saved question',
        'answer': 1,
      };
      var calls = 0;
      Completer<http.Response>? pending;
      final remote = SupabaseClient(
        'https://example.supabase.co',
        'fixture',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((r) async {
          calls++;
          if (pending != null) {
            final response = await pending.future;
            return http.Response(
              response.body,
              response.statusCode,
              request: r,
              headers: response.headers,
            );
          }
          return http.Response(
            jsonEncode([saved]),
            200,
            request: r,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(remote.dispose);
      final s = SnapshotStore(await SharedPreferences.getInstance(), {
        'questions': [q],
      }, remote)..reload();
      s.state['active'] = {
        'id': 'first',
        'ids': ['same-id'],
        'index': 0,
        'score': 0,
      };
      expect(s.currentOrNull, isNull);
      await s.fetchJourneyQuestions();
      expect(s.current.data['version'], 2);
      expect(s.current.answer, 1);
      expect(s.questions.single.data['version'], 9);
      s.reload();
      expect(s.current.data['version'], 2);
      await s.fetchJourneyQuestions();
      expect(calls, 1);
      s.state['active'] = {
        'id': 'second',
        'ids': ['same-id'],
        'index': 0,
      };
      expect(s.currentOrNull, isNull);
      pending = Completer<http.Response>();
      final lateReply = s.fetchJourneyQuestions();
      await Future<void>.delayed(Duration.zero);
      s.state['active'] = {
        'id': 'third',
        'ids': ['same-id'],
        'index': 0,
      };
      pending.complete(
        http.Response(
          jsonEncode([saved]),
          200,
          headers: {'content-type': 'application/json'},
        ),
      );
      await lateReply;
      expect(s.currentOrNull, isNull);
      expect(s.state['journey_snapshot']['session'], 'first');
      s.owner = 'another-owner';
      expect(s.currentOrNull, isNull);
      s.reload();
      expect(s.state['journey_snapshot'], isNull);
    },
  );
}
