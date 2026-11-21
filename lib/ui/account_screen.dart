import 'app_version.dart';
import 'package:flutter/material.dart';
import '../data/game_store.dart';
import 'auth_screen.dart';
import 'editorial_screen.dart';
import 'components.dart';
import 'garden_backdrop.dart';
import 'quest_materials.dart';

/// Account, saved progress and information about the application.
class AccountScreen extends StatefulWidget {
  final GameStore store;
  const AccountScreen({super.key, required this.store});
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  bool busy = false;
  String? error;
  bool ornithoAdmin = false;
  @override
  void initState() {
    super.initState();
    checkEditorialAccess();
  }

  Future<void> checkEditorialAccess() async {
    final owner = widget.store.identity;
    bool allowed = false;
    if (widget.store.cloud) {
      try {
        allowed = await widget.store.client.rpc('is_ornitho_admin') == true;
      } catch (_) {
        /* Fail closed. */
      }
    }
    if (mounted && owner == widget.store.identity) {
      setState(() => ornithoAdmin = allowed);
    }
  }

  Future<void> account({bool create = false}) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (widget.store.cloud) {
        await widget.store.client.auth.signOut();
      } else {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                AuthScreen(store: widget.store, createAccount: create),
          ),
        );
      }
      widget.store.reload();
      await widget.store.refresh();
      await checkEditorialAccess();
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'La connexion n’a pas abouti. Réessaie quand le réseau est disponible.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Mon compte')),
      bottomNavigationBar: const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Text('Version $appVersionLabel', textAlign: TextAlign.center),
        ),
      ),
      body: GardenBackdrop(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (ornithoAdmin && widget.store.cloud)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.fact_check),
                      title: const Text('Ornitho admin'),
                      subtitle: const Text(
                        'Relire et valider les fiches, photos et chants',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: busy
                          ? null
                          : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EditorialScreen(
                                  client: widget.store.client,
                                ),
                              ),
                            ),
                    ),
                  ),
                FieldPaper(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Compte et sauvegarde',
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                          color: ink,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.store.cloud
                            ? 'Compte connecté : les parties et les plumes sont synchronisées.'
                            : 'Connecte-toi pour jouer et sauvegarder ta progression.',
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Tu peux synchroniser tes coches, dates, notes et positions GPS en activant la synchronisation dans le carnet. Tes balades et tes plumes sont liées à ton compte.',
                      ),
                      const SizedBox(height: 16),
                      if (error != null)
                        Text(
                          error!,
                          style: const TextStyle(color: Colors.deepOrange),
                        ),
                      FilledButton(
                        onPressed: busy ? null : account,
                        child: Text(
                          busy
                              ? 'Un instant…'
                              : widget.store.cloud
                              ? 'Se déconnecter'
                              : 'Se connecter',
                        ),
                      ),
                      if (!widget.store.cloud)
                        TextButton(
                          onPressed: busy ? null : () => account(create: true),
                          child: const Text('Créer un compte gratuit'),
                        ),
                      const SizedBox(height: 24),
                      const Text(
                        'Sources',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          color: ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Les fiches citent la Station ornithologique suisse, le Muséum national d’Histoire naturelle et la LPO. Les liens et crédits photo sont disponibles dans le carnet et les jeux.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
