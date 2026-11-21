import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
// ignore: depend_on_referenced_packages
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:petit_ornitho/data/game_store.dart';

class _Store extends GameStore {
  _Store(SharedPreferences prefs, this.backend) : super(prefs, {}, []);
  final SupabaseClient backend;
  @override
  SupabaseClient get client => backend;
}

void main() {
  test(
    'Une session confirmée sauvegarde et retrouve uniquement son profil',
    () async {
      SharedPreferences.setMockInitialValues({'ornitho_v1_guest': '{"xp":15}'});
      final prefs = await SharedPreferences.getInstance();
      const account = '11111111-1111-4111-8111-111111111111';
      const email = 'ornitho@example.invalid';
      final user = {
        'id': account,
        'email': email,
        'aud': 'authenticated',
        'role': 'authenticated',
        'app_metadata': {},
        'user_metadata': {},
        'created_at': '2026-01-01T00:00:00Z',
      };
      final calls = <String>[];
      final client = SupabaseClient(
        'https://example.invalid',
        'fixture',
        authOptions: const AuthClientOptions(
          autoRefreshToken: false,
          authFlowType: AuthFlowType.implicit,
        ),
        httpClient: MockClient((req) async {
          calls.add(req.url.path);
          final result = switch (req.url.path) {
            '/auth/v1/signup' => user,
            '/auth/v1/token' => {
              'access_token': 'fixture',
              'refresh_token': 'fixture',
              'token_type': 'bearer',
              'expires_in': 3600,
              'user': user,
            },
            '/auth/v1/logout' => {},
            _ => throw StateError(req.url.path),
          };
          return http.Response(
            jsonEncode(result),
            200,
            headers: {'content-type': 'application/json'},
            request: req,
          );
        }),
      );
      addTearDown(client.dispose);
      final store = _Store(prefs, client)..reload();
      expect(store.xp, 15);
      final signup = await client.auth.signUp(
        email: email,
        password: 'example-fixture',
      );
      expect(signup.session, isNull);
      await client.auth.signInWithPassword(
        email: email,
        password: 'example-fixture',
      );
      store.reload();
      expect(store.identity, account);
      expect(store.xp, 0);
      store.state['xp'] = 45;
      await store.save();
      expect((_Store(prefs, client)..reload()).xp, 45);
      await client.auth.signOut();
      store.reload();
      expect(store.identity, 'guest');
      expect(store.xp, 15);
      await client.auth.signInWithPassword(
        email: email,
        password: 'example-fixture',
      );
      store.reload();
      expect(store.xp, 45);
      expect(calls, [
        '/auth/v1/signup',
        '/auth/v1/token',
        '/auth/v1/logout',
        '/auth/v1/token',
      ]);
    },
  );
}
