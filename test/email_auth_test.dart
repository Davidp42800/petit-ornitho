import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
// ignore: depend_on_referenced_packages
import 'package:http/testing.dart';
import 'package:petit_ornitho/data/game_store.dart';
import 'package:petit_ornitho/ui/auth_screen.dart';

class _AccountStore extends GameStore {
  _AccountStore(SharedPreferences prefs, this.remote) : super(prefs, {}, []);
  final SupabaseClient remote;
  @override
  SupabaseClient get client => remote;
}

void main() {
  for (final immediate in [true, false]) {
    testWidgets(
      immediate
          ? 'Une inscription connecte immédiatement et ramène au jeu'
          : 'Créer un compte, confirmer par e-mail et corriger une connexion refusée',
      (t) async {
        SharedPreferences.setMockInitialValues({});
        final paths = <String>[];
        final user = {
          'id': '11111111-1111-4111-8111-111111111111',
          'aud': 'authenticated',
          'role': 'authenticated',
          'email': 'test@example.org',
          'app_metadata': {},
          'user_metadata': {},
          'created_at': '2026-11-21T08:00:00Z',
        };
        final client = SupabaseClient(
          'https://example.supabase.co',
          'test',
          authOptions: const AuthClientOptions(
            autoRefreshToken: false,
            authFlowType: AuthFlowType.implicit,
          ),
          httpClient: MockClient((req) async {
            paths.add(req.url.path);
            final body = jsonDecode(req.body);
            expect(body['email'], 'test@example.org');
            expect(body['password'], 'azerty%12345');
            final registering = req.url.path.endsWith('/signup');
            return http.Response(
              jsonEncode(
                registering && !immediate
                    ? user
                    : immediate || paths.length == 3
                    ? {
                        'user': user,
                        'access_token':
                            'eyJhbGciOiJIUzI1NiJ9.eyJleHAiOjIwMDAwMDAwMDB9.fixture',
                        'token_type': 'bearer',
                        'refresh_token': 'fixture',
                        'expires_in': 3600,
                      }
                    : {
                        'code': 'invalid_credentials',
                        'message': 'Invalid login credentials',
                      },
              ),
              registering || paths.length == 3 ? 200 : 400,
              request: req,
              headers: {
                'content-type': 'application/json',
                'x-supabase-api-version': '2024-01-01',
              },
            );
          }),
        );
        final store = _AccountStore(
          await SharedPreferences.getInstance(),
          client,
        );
        t.view.physicalSize = const Size(850, 1100);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        await t.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AuthScreen(store: store)),
                  ),
                  child: const Text('Mon parcours'),
                ),
              ),
            ),
          ),
        );
        await t.tap(find.text('Mon parcours'));
        await t.pumpAndSettle();
        expect(find.textContaining('Google'), findsNothing);
        await t.tap(find.text('Créer un compte'));
        await t.pump();
        await t.enterText(
          find.byType(TextFormField).first,
          ' test@example.org ',
        );
        await t.enterText(find.byType(TextFormField).last, 'azerty%12345');
        await t.pump();
        await t.runAsync(() async {
          await t.tap(find.text('Créer mon compte'));
          await Future<void>.delayed(const Duration(milliseconds: 40));
        });
        await t.pumpAndSettle();
        if (immediate) {
          expect(find.text('Mon parcours'), findsOneWidget);
          expect(client.auth.currentUser?.email, 'test@example.org');
          expect(paths, ['/auth/v1/signup']);
          await t.pumpWidget(const SizedBox.shrink());
          return;
        }
        expect(find.textContaining('Vérifie ta boîte mail'), findsOneWidget);
        await t.runAsync(() async {
          await t.tap(find.text('Se connecter'));
          await Future<void>.delayed(const Duration(milliseconds: 40));
        });
        await t.pumpAndSettle();
        expect(
          find.text('Adresse e-mail ou mot de passe incorrect.'),
          findsOneWidget,
        );
        await t.runAsync(() async {
          await t.tap(find.text('Se connecter'));
          await Future<void>.delayed(const Duration(milliseconds: 40));
        });
        await t.pumpAndSettle();
        expect(find.text('Mon parcours'), findsOneWidget);
        expect(client.auth.currentUser?.email, 'test@example.org');
        expect(paths, ['/auth/v1/signup', '/auth/v1/token', '/auth/v1/token']);
        await t.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
