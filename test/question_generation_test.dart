import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
// ignore: depend_on_referenced_packages
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:petit_ornitho/ui/question_generation.dart';

void main() {
  testWidgets(
    'Une relance conserve son identifiant et les résultats sont consultables',
    (t) async {
      SharedPreferences.setMockInitialValues({});
      final requests = <String>[];
      final gate = Completer<void>();
      var attempts = 0;
      final client = (await t.runAsync(
        () async => SupabaseClient(
          'https://example.supabase.co',
          'fixture',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient((r) async {
            dynamic result;
            if (r.url.path.endsWith('/question_generation_history')) {
              result = attempts >= 2
                  ? [
                      {
                        'status': 'published',
                        'created_at': '2026-10-03',
                        'seed_id': 'seed',
                        'seed_version': 1,
                        'result': {'id': 'llm_result'},
                      },
                    ]
                  : [];
            } else {
              requests.add(jsonDecode(r.body)['request_id'] as String);
              attempts++;
              if (attempts == 1) {
                await gate.future;
                return http.Response(
                  '{"error":"lost_response"}',
                  503,
                  headers: {'content-type': 'application/json'},
                  request: r,
                );
              }
              result = {'status': 'published'};
            }
            return http.Response(
              jsonEncode(result),
              200,
              headers: {'content-type': 'application/json'},
              request: r,
            );
          }),
        ),
      ))!;
      addTearDown(() => t.runAsync(client.dispose));
      await t.pumpWidget(
        MaterialApp(
          home: QuestionGenerationScreen(
            client: client,
            seed: const {
              'id': 'seed',
              'version': 1,
              'prompt': 'Où est le nid ?',
            },
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.runAsync(() async {
        await t.tap(find.text('Créer une variante'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await t.pump();
      await t.tap(find.text('Création en cours…'));
      await t.pump();
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      expect(requests.length, 1);
      await t.runAsync(() async {
        gate.complete();
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await t.pumpAndSettle();
      expect(find.textContaining('Résultat non confirmé'), findsOneWidget);
      await t.runAsync(() async {
        await t.tap(find.text('Créer une variante'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await t.pumpAndSettle();
      expect(requests.length, 2);
      expect(requests[0], requests[1]);
      await t.scrollUntilVisible(
        find.text('Question publiée'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Question publiée'), findsOneWidget);
      expect(
        find.textContaining('Nouvelle question publiée !'),
        findsOneWidget,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getKeys().where((k) => k.startsWith('generation:')),
        isEmpty,
      );
      expect(t.takeException(), isNull);
    },
  );
}
