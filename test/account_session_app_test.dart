import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:petit_ornitho/data/game_store.dart';
import 'package:petit_ornitho/ui/account_session_app.dart';
import 'package:petit_ornitho/ui/auth_screen.dart';
import 'package:petit_ornitho/ui/home_screen.dart';

class AccountStore extends GameStore {
  final SupabaseClient remote;
  AccountStore(SharedPreferences prefs, this.remote)
    : super(
        prefs,
        jsonDecode(File('assets/data/content.json').readAsStringSync()),
        [],
      );
  @override
  SupabaseClient get client => remote;
  @override
  Future<void> refresh() async {}
}

void main() {
  late SupabaseClient client;
  late AccountStore store;
  const first = '11111111-1111-4111-8111-111111111111';
  const second = '22222222-2222-4222-8222-222222222222';
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'ornitho_v1_guest': '{"xp":15}',
      'ornitho_v1_$first': '{"xp":55}',
    });
    client = SupabaseClient(
      'https://example.invalid',
      'fixture',
      authOptions: const AuthClientOptions(
        autoRefreshToken: false,
        authFlowType: AuthFlowType.implicit,
      ),
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/logout')) {
          return http.Response('{}', 200);
        }
        final address = jsonDecode(request.body)['email'];
        final user = {
          'id': address == 'second@example.invalid' ? second : first,
          'email': address,
          'aud': 'authenticated',
          'role': 'authenticated',
          'app_metadata': {},
          'user_metadata': {},
          'created_at': '2026-01-01T00:00:00Z',
        };
        return http.Response(
          jsonEncode(
            request.url.path.endsWith('/signup')
                ? user
                : {
                    'user': user,
                    'access_token': 'fixture',
                    'token_type': 'bearer',
                    'refresh_token': 'fixture',
                    'expires_in': 3600,
                  },
          ),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    store = AccountStore(await SharedPreferences.getInstance(), client)
      ..reload();
  });
  tearDown(() async => client.dispose());

  testWidgets(
    'Compte obligatoire, confirmation puis reprise isolée et fermeture des routes à la déconnexion',
    (t) async {
      await t.pumpWidget(AccountSessionApp(store: store));
      await t.pumpAndSettle();
      expect(find.byType(AuthScreen), findsOneWidget);
      expect(find.byType(Home), findsNothing);
      expect(find.text('Revenir au jeu'), findsNothing);
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(find.byType(Home), findsNothing);
      await t.runAsync(() async {
        await client.auth.signUp(
          email: 'first@example.invalid',
          password: 'fixture-password',
        );
      });
      await t.pumpAndSettle();
      expect(find.byType(Home), findsNothing);
      await t.runAsync(() async {
        await client.auth.signInWithPassword(
          email: 'first@example.invalid',
          password: 'fixture-password',
        );
      });
      await t.pumpAndSettle();
      expect(find.byType(Home), findsOneWidget);
      expect(store.xp, 55);
      final context = t.element(find.byType(Home));
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              const Scaffold(body: Text('Partie du premier compte')),
        ),
      );
      await t.pumpAndSettle();
      await t.runAsync(() async => client.auth.signOut());
      await t.pumpAndSettle();
      expect(find.byType(AuthScreen), findsOneWidget);
      expect(find.text('Partie du premier compte'), findsNothing);
      await t.runAsync(() async {
        await client.auth.signInWithPassword(
          email: 'second@example.invalid',
          password: 'fixture-password',
        );
      });
      await t.pumpAndSettle();
      expect(store.xp, 0);
      expect(store.prefs.getString('ornitho_v1_$first'), '{"xp":55}');
      expect(store.prefs.getString('ornitho_v1_guest'), '{"xp":15}');
      await t.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('Session déjà connectée : reprise du compte au démarrage', (
    t,
  ) async {
    await t.runAsync(() async {
      await client.auth.signInWithPassword(
        email: 'first@example.invalid',
        password: 'fixture-password',
      );
    });
    await t.pumpWidget(AccountSessionApp(store: store));
    await t.pumpAndSettle();
    expect(find.byType(Home), findsOneWidget);
    expect(store.xp, 55);
    await t.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Inscription obligatoire utilisable à 390 px et texte agrandi', (
    t,
  ) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = 1.7;
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(AccountSessionApp(store: store));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.text('Créer un compte'), 200,
        scrollable: find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)).first);
    await t.tap(find.text('Créer un compte'));
    await t.pumpAndSettle();
    expect(find.text('Créer mon compte'), findsOneWidget);
    expect(find.text('Revenir au jeu'), findsNothing);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
  });
}
