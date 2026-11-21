import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
// ignore: depend_on_referenced_packages
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:petit_ornitho/ui/content_report_inbox.dart';

void main() {
  testWidgets(
    'Le signalement ne quitte la liste qu’après décision enregistrée',
    (t) async {
      var attempts = 0;
      final client = (await t.runAsync(
        () async => SupabaseClient(
          'https://example.supabase.co',
          'fixture',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient((request) async {
            final headers = {'content-type': 'application/json; charset=utf-8'};
            if (request.url.path.endsWith('/list_content_reports')) {
              return http.Response(
                jsonEncode(
                  attempts < 2
                      ? [
                          {
                            'id': 'fixture',
                            'comment': 'Vérifier la photo',
                            'species_id': 'robin',
                            'photo_ref': 'assets/birds/test.jpg',
                          },
                        ]
                      : [],
                ),
                200,
                request: request,
                headers: headers,
              );
            }
            expect(request.url.path, endsWith('/review_content_report'));
            expect(jsonDecode(request.body), {
              'p_id': 'fixture',
              'p_status': 'resolved',
            });
            attempts++;
            return attempts == 1
                ? http.Response(
                    '{"message":"indisponible"}',
                    503,
                    request: request,
                    headers: headers,
                  )
                : http.Response('', 204, request: request);
          }),
        ),
      ))!;
      addTearDown(() => t.runAsync(client.dispose));
      await t.pumpWidget(MaterialApp(home: ContentReportInbox(client: client)));
      await t.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (w) => w is SelectableText && w.data == 'Vérifier la photo',
        ),
        findsOneWidget,
      );
      await t.tap(find.text('Marquer comme résolu'));
      await t.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (w) => w is SelectableText && w.data == 'Vérifier la photo',
        ),
        findsOneWidget,
      );
      await t.tap(find.text('Marquer comme résolu'));
      await t.pumpAndSettle();
      expect(find.text('Aucun signalement en attente.'), findsOneWidget);
    },
  );
}
