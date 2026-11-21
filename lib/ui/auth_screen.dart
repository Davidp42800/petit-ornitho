import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'garden_backdrop.dart';
import 'quest_materials.dart';
import '../data/game_store.dart';
import 'components.dart';

class AuthScreen extends StatefulWidget {
  final GameStore store;
  final bool createAccount;
  final bool requiredForPlay;
  const AuthScreen({
    super.key,
    required this.store,
    this.createAccount = false,
    this.requiredForPlay = false,
  });
  @override
  State<AuthScreen> createState() => _AuthState();
}

class _AuthState extends State<AuthScreen> {
  StreamSubscription<AuthState>? subscription;
  final email = TextEditingController();
  final password = TextEditingController();
  final formKey = GlobalKey<FormState>();
  bool creating = false;
  bool hidePassword = true;
  bool busy = false;
  bool closing = false;
  String? message;
  @override
  void initState() {
    super.initState();
    creating = widget.createAccount;
    subscription = widget.store.client.auth.onAuthStateChange.listen(
      (state) {
        if (mounted &&
            !widget.requiredForPlay &&
            !closing &&
            state.event == AuthChangeEvent.signedIn &&
            state.session != null) {
          closing = true;
          Navigator.of(context).pop();
        }
      },
      onError: (Object _) {
        if (mounted) {
          setState(() {
            busy = false;
            message = 'La connexion n’a pas abouti. Tu peux réessayer.';
          });
        }
      },
    );
  }

  @override
  void dispose() {
    subscription?.cancel();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> signInWithEmail() async {
    if (busy || !(formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final address = email.text.trim();
      if (creating) {
        final response = await widget.store.client.auth.signUp(
          email: address,
          password: password.text,
          emailRedirectTo: kIsWeb
              ? Uri.base.resolveUri(Uri(path: Uri.base.path)).toString()
              : null,
        );
        if (mounted && response.session == null) {
          setState(() {
            creating = false;
            message =
                'Vérifie ta boîte mail. Si un lien de confirmation t’a été envoyé, ouvre-le puis connecte-toi.';
          });
        }
      } else {
        await widget.store.client.auth.signInWithPassword(
          email: address,
          password: password.text,
        );
      }
    } on AuthException catch (error) {
      if (mounted) {
        setState(
          () => message = switch (error.code) {
            'email_not_confirmed' =>
              'Confirme ton adresse avec le lien reçu par e-mail, puis reconnecte-toi.',
            'weak_password' =>
              'Choisis un mot de passe plus long et plus varié.',
            'over_email_send_rate_limit' || 'over_request_rate_limit' =>
              'Trop de tentatives. Patiente un moment avant de réessayer.',
            'invalid_credentials' =>
              'Adresse e-mail ou mot de passe incorrect.',
            'signup_disabled' =>
              'La création de compte est momentanément indisponible.',
            _ =>
              creating
                  ? 'Impossible de créer le compte. Vérifie les champs puis réessaie.'
                  : 'Connexion impossible. Vérifie ton e-mail et ton mot de passe.',
          },
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => message =
              'Connexion indisponible. Vérifie ta connexion Internet et réessaie.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      automaticallyImplyLeading: !widget.requiredForPlay,
      title: Text(creating ? 'Inscription' : 'Connexion'),
    ),
    body: GardenBackdrop(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FieldPaper(
              padding: EdgeInsets.zero,
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(28),
                children: [
                  Text(
                    creating ? 'Crée ton compte' : 'Retrouve ton aventure',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    creating
                        ? 'Utilise ton adresse e-mail pour sauvegarder ta progression.'
                        : 'Connecte-toi pour jouer et retrouver ta progression.',
                  ),
                  const SizedBox(height: 24),
                  Form(
                    key: formKey,
                    child: AutofillGroup(
                      child: Column(
                        children: [
                          TextFormField(
                            controller: email,
                            enabled: !busy,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.username],
                            autocorrect: false,
                            decoration: const InputDecoration(
                              labelText: 'Adresse e-mail',
                            ),
                            validator: (value) =>
                                RegExp(
                                  r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                ).hasMatch(value?.trim() ?? '')
                                ? null
                                : 'Indique une adresse e-mail valide.',
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: password,
                            enabled: !busy,
                            obscureText: hidePassword,
                            autocorrect: false,
                            enableSuggestions: false,
                            autofillHints: [
                              creating
                                  ? AutofillHints.newPassword
                                  : AutofillHints.password,
                            ],
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => signInWithEmail(),
                            decoration: InputDecoration(
                              labelText: 'Mot de passe',
                              suffixIcon: IconButton(
                                tooltip: hidePassword
                                    ? 'Afficher le mot de passe'
                                    : 'Masquer le mot de passe',
                                onPressed: busy
                                    ? null
                                    : () => setState(
                                        () => hidePassword = !hidePassword,
                                      ),
                                icon: Icon(
                                  hidePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                            validator: (value) => value == null || value.isEmpty
                                ? 'Indique ton mot de passe.'
                                : null,
                          ),
                          const SizedBox(height: 20),
                          FilledButton(
                            onPressed: busy ? null : signInWithEmail,
                            child: Text(
                              busy
                                  ? 'Un instant…'
                                  : creating
                                  ? 'Créer mon compte'
                                  : 'Se connecter',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => setState(() {
                            creating = !creating;
                            message = null;
                            password.clear();
                            hidePassword = true;
                          }),
                    child: Text(
                      creating ? 'J’ai déjà un compte' : 'Créer un compte',
                    ),
                  ),
                  if (message != null)
                    Semantics(liveRegion: true, child: Text(message!)),
                  const SizedBox(height: 20),
                  const Text(
                    'Un compte gratuit est nécessaire pour jouer. Tes balades et tes plumes sont sauvegardées dans ton compte.',
                  ),
                  if (!widget.requiredForPlay)
                    TextButton(
                      onPressed: busy ? null : () => Navigator.pop(context),
                      child: const Text('Revenir au jeu'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
