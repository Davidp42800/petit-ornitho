import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
// ignore: depend_on_referenced_packages
import 'package:http/testing.dart';
import 'package:petit_ornitho/ui/content_report.dart';
import 'package:petit_ornitho/data/game_store.dart';

class ReportStore extends GameStore {
  ReportStore(SharedPreferences prefs, this.remote) : super(prefs, {}, []);
  final SupabaseClient remote;
  @override
  SupabaseClient get client => remote;
}

void main() {
  test('Seul un UUID confirme le signalement via RPC', () async {
    SharedPreferences.setMockInitialValues({});
    final requests = <Map>[];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((req) async {
        expect(req.url.path, '/rest/v1/rpc/submit_content_report');
        requests.add(jsonDecode(req.body) as Map);
        return http.Response(
          jsonEncode(
            requests.length == 1
                ? null
                : '11111111-2222-4333-8444-555555555555',
          ),
          200,
          request: req,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.dispose);
    final store = ReportStore(await SharedPreferences.getInstance(), client);
    await expectLater(
      store.submitContentReport(
        speciesId: 'robin',
        questionId: 'q1',
        version: 2,
        comment: 'test',
      ),
      throwsStateError,
    );
    await store.submitContentReport(
      speciesId: 'robin',
      photo: 'assets/birds/robin.jpg',
      comment: 'test',
    );
    expect(requests, [
      {
        'p_species_id': 'robin',
        'p_question_id': 'q1',
        'p_question_version': 2,
        'p_photo_ref': null,
        'p_comment': 'test',
      },
      {
        'p_species_id': 'robin',
        'p_question_id': null,
        'p_question_version': null,
        'p_photo_ref': 'assets/birds/robin.jpg',
        'p_comment': 'test',
      },
    ]);
  });
  testWidgets('Une erreur garde le commentaire pour réessayer', (t) async {
    var calls = 0;
    bool? sent;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                sent = await showDialog<bool>(
                  context: context,
                  builder: (_) => ContentReportDialog(
                    title: 'Signaler cette photo',
                    send: (comment) async {
                      expect(comment, 'Vérifier la légende.');
                      if (++calls == 1) throw StateError('offline');
                    },
                  ),
                );
              },
              child: const Text('Ouvrir'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('Ouvrir'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), '  Vérifier la légende.  ');
    await t.pump();
    await t.tap(find.text('Envoyer'));
    await t.pumpAndSettle();
    expect(find.text('Envoi impossible. Réessaie.'), findsOneWidget);
    expect(sent, isNull);
    await t.tap(find.text('Envoyer'));
    await t.pumpAndSettle();
    expect(sent, isTrue);
  });
}
