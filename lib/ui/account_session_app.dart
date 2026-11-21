import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/game_store.dart';
import 'app.dart';
import 'auth_screen.dart';

/// The production entry point. A change of account replaces the whole navigator
/// so Back cannot reopen another player's game after logout or account switching.
class AccountSessionApp extends StatefulWidget {
  final GameStore store;
  const AccountSessionApp({super.key, required this.store});

  @override
  State<AccountSessionApp> createState() => _AccountSessionAppState();
}

class _AccountSessionAppState extends State<AccountSessionApp> {
  StreamSubscription<AuthState>? subscription;
  String? owner;
  bool unreadable = false;

  String? get sessionOwner {
    final session = widget.store.client.auth.currentSession;
    if (session == null || session.user.isAnonymous) return null;
    return session.user.id;
  }

  @override
  void initState() {
    super.initState();
    owner = sessionOwner;
    loadProfile();
    subscription = widget.store.client.auth.onAuthStateChange.listen(
      (_) {
        if (!mounted || sessionOwner == owner) return;
        setState(() {
          owner = sessionOwner;
          loadProfile();
        });
      },
      onError: (Object _) {
        // A network refresh failure does not erase an existing account save.
        // A revoked/removed session still closes every game route.
        if (mounted && sessionOwner != owner) {
          setState(() {
            owner = sessionOwner;
            loadProfile();
          });
        }
      },
    );
  }

  void loadProfile() {
    unreadable = false;
    if (owner == null) return;
    try {
      widget.store.reload();
    } catch (_) {
      unreadable = true;
    }
  }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => OrnithoApp(
    key: ValueKey(owner),
    store: widget.store,
    entryScreen: owner == null
        ? AuthScreen(store: widget.store, requiredForPlay: true)
        : unreadable
        ? Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Ta sauvegarde n’a pas pu être ouverte. Elle est conservée.',
                  ),
                  TextButton(
                    onPressed: () => setState(loadProfile),
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            ),
          )
        : null,
  );
}
