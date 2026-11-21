import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'data/game_store.dart';
import 'ui/account_session_app.dart';
import 'ui/pio.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Startup());
}

/// A failed initialization must offer recovery, not leave a blank screen or
/// silently erase the stored progress.
class Startup extends StatefulWidget {
  const Startup({super.key});
  @override
  State<Startup> createState() => _StartupState();
}

class _StartupState extends State<Startup> {
  bool initialized = false;
  late Future<GameStore> loading = load();
  Future<GameStore> load() async {
    if (!initialized) {
      await Supabase.initialize(
        url: 'https://gwipiyamzhuohxqfjljh.supabase.co',
        publishableKey: const String.fromEnvironment(
          'SUPABASE_KEY',
          defaultValue: 'sb_publishable_J_fzL2gtJzaBJ_T37mZ9_w_ptdlVwWF',
        ),
      );
      initialized = true;
    }
    return GameStore.load();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<GameStore>(
    future: loading,
    builder: (context, snapshot) {
      if (snapshot.hasData) return AccountSessionApp(store: snapshot.data!);
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xffe6f5fd),
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Pio(size: 140),
                    const SizedBox(height: 20),
                    Text(
                      snapshot.hasError
                          ? 'Pépi n’a pas pu ouvrir le jeu. Ta sauvegarde n’a pas été effacée.'
                          : 'Pépi prépare les jeux…',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    if (snapshot.hasError)
                      FilledButton(
                        onPressed: () => setState(() => loading = load()),
                        child: const Text('Réessayer'),
                      )
                    else
                      const CircularProgressIndicator(),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
