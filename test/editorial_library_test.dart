import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// Existing transitive dependency supplied by supabase_flutter.
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
// ignore: depend_on_referenced_packages
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:petit_ornitho/ui/editorial_screen.dart';

void main() {
  for (final media in [false, true]) {
  testWidgets('Bibliothèque : consulter et rechercher (média: $media)', (
    t,
  ) async {
    final requests = <Map<String, dynamic>>[];
    final client = (await t.runAsync(
      () async => SupabaseClient(
        'https://example.supabase.co',
        'fixture',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/editorial_catalogue')) {
            return http.Response(
              '[]',
              200,
              request: request,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          final args = Map<String, dynamic>.from(jsonDecode(request.body));
          requests.add(args);
          final retired = args['p_status'] == 'retired';
          final found = args['p_search'] == '';
          return http.Response(
            jsonEncode({
              'total': found ? 1 : 0,
              'items': found
                  ? [
                      {
                        'id': 'fixture',
                        'entry_type': media ? 'media' : 'knowledge',
                        'kind': media ? 'audio' : 'quiz',
                        if (media) 'recording': {'author':'Auteur de test','license':'cc-by','source':'https://xeno-canto.org/1'},
                        'version': 1,
                        'species_name': 'Martin-pêcheur',
                        'status': retired ? 'retired' : 'published',
                        'prompt': 'Où est mon nid ?',
                        'options': ['Dans une berge', 'Sur l’eau'],
                        'answer': 0,
                        'hint': 'Regarde la berge',
                        'explanation': 'Un terrier abrite la nichée.',
                        'fact': {
                          'statement': 'Niche en terrier.',
                          'status': 'published',
                          'page': 1,
                        },
                        'source': {'url': 'https://example.org/source'},
                        'history': retired
                            ? [
                                {
                                  'decision': 'reject',
                                  'reviewer_name': 'Admin de test',
                                  'reviewed_at': '2026-10-03',
                                  'note': 'Proposition ambiguë à corriger.',
                                },
                              ]
                            : [],
                      },
                    ]
                  : [],
            }),
            200,
            request: request,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      ),
    ))!;
    addTearDown(() => t.runAsync(client.dispose));
    await t.pumpWidget(MaterialApp(home: EditorialScreen(client: client)));
    await t.pumpAndSettle();
    await t.tap(find.text('Toutes les questions'));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
      find.text('Où est mon nid ?'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await t.pumpAndSettle();
    expect(find.text('Où est mon nid ?'), findsOneWidget);
    if (media) {
      expect(find.text('Identification au son'), findsOneWidget);
      expect(find.text('Remettre en jeu'), findsNothing);
    }
    await t.ensureVisible(find.text('Écartées'));
    await t.pumpAndSettle();
    await t.tap(find.text('Écartées'));
    await t.pumpAndSettle();
    expect(requests.last['p_status'], 'retired');
    await t.scrollUntilVisible(
      find.textContaining('Proposition ambiguë à corriger.'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Admin de test'), findsOneWidget);
    expect(
      find.textContaining('Proposition ambiguë à corriger.'),
      findsOneWidget,
    );
    await t.scrollUntilVisible(
      find.byType(TextField),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await t.enterText(find.byType(TextField), 'introuvable');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();
    expect(requests.last['p_search'], 'introuvable');
    expect(find.text('Aucune question pour cette recherche.'), findsOneWidget);
    expect(find.text('Où est mon nid ?'), findsNothing);
    expect(t.takeException(), isNull);
  });
  }
}
