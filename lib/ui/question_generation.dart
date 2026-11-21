import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A persisted request key makes a retry safe even after closing the screen.
String newGenerationRequestId() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

class QuestionGenerationScreen extends StatefulWidget {
  final SupabaseClient client;
  final Map<String, dynamic>? seed;
  const QuestionGenerationScreen({super.key, required this.client, this.seed});
  @override
  State<QuestionGenerationScreen> createState() => _QuestionGenerationState();
}

class _QuestionGenerationState extends State<QuestionGenerationScreen> {
  List<dynamic> jobs = [];
  bool loading = false, generating = false;
  String? message, error;
  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await widget.client.rpc('question_generation_history');
      if (mounted) setState(() => jobs = result as List);
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Historique indisponible. Réessayez.');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> generate() async {
    if (generating) return;
    setState(() {
      generating = true;
      error = null;
      message = 'Pépi prépare une scène de terrain…';
    });
    SharedPreferences? prefs;
    String? key;
    try {
      final seed = widget.seed!;
      prefs = await SharedPreferences.getInstance();
      key =
          'generation:${widget.client.auth.currentUser?.id}:${seed['id']}:${seed['version']}';
      final request = prefs.getString(key) ?? newGenerationRequestId();
      // Never send a paid request unless its retry identity has been saved.
      if (!await prefs.setString(key, request)) throw StateError('storage');
      final response = await widget.client.functions.invoke(
        'question-generator',
        body: {
          'seed_id': seed['id'],
          'version': seed['version'],
          'request_id': request,
        },
      );
      final data = Map<String, dynamic>.from(response.data as Map);
      final status = data['status'];
      if (status == 'published' || status == 'failed') await prefs.remove(key);
      if (mounted) {
        setState(
          () => message = switch (status) {
            'published' =>
              'Nouvelle question publiée ! Retrouvez-la dans la bibliothèque.',
            'failed' =>
              'La variante n’a pas passé les contrôles. Aucune question ajoutée.',
            _ =>
              'Demande enregistrée. Actualisez l’historique pour suivre son résultat.',
          },
        );
      }
      await refresh();
    } on FunctionException catch (e) {
      final data = e.details;
      if (data is Map && data['status'] == 'failed') {
        if (prefs != null && key != null) await prefs.remove(key);
        if (mounted) {
          setState(
            () => message =
                'La variante n’a pas passé les contrôles. Aucune question ajoutée.',
          );
        }
        await refresh();
      } else if (mounted) {
        setState(() {
          message = null;
          error =
              'Résultat non confirmé. Consultez l’historique ou réessayez : la même demande sera reprise sans génération en double.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          message = null;
          error =
              'Résultat non confirmé. Consultez l’historique ou réessayez : la même demande sera reprise sans génération en double.';
        });
      }
    } finally {
      if (mounted) setState(() => generating = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Atelier de questions'),
      actions: [
        IconButton(
          tooltip: 'Actualiser l’historique',
          onPressed: loading ? null : refresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Des scènes de terrain avec Pépi',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Une variante s’appuie sur les faits publiés de l’espèce. Les réponses restent inchangées ; le texte passe un contrôle automatique avant publication. Limite partagée : 20 demandes par jour.',
            ),
            if (widget.seed != null) ...[
              const SizedBox(height: 16),
              Text('Question de départ : ${widget.seed!['prompt']}'),
              FilledButton.icon(
                onPressed: generating ? null : generate,
                icon: const Icon(Icons.auto_awesome),
                label: Text(
                  generating ? 'Création en cours…' : 'Créer une variante',
                ),
              ),
            ],
            if (loading || generating) const LinearProgressIndicator(),
            if (message != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(message!),
              ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 20),
            const Text(
              'Historique des 100 dernières demandes',
              style: TextStyle(fontSize: 20),
            ),
            if (!loading && jobs.isEmpty)
              const Text('Aucune demande enregistrée.'),
            for (final job in jobs)
              Card(
                child: ExpansionTile(
                  title: Text(switch (job['status']) {
                    'published' => 'Question publiée',
                    'failed' => 'Non publiée',
                    'running' => 'Génération en cours',
                    _ => 'En attente',
                  }),
                  subtitle: SelectableText(
                    '${job['created_at']}\nDépart : ${job['seed_id']} · version ${job['seed_version']}${job['result']?['id'] != null ? '\nQuestion : ${job['result']['id']}' : ''}${job['error_code'] != null ? '\nMotif : ${job['error_code']}' : ''}',
                  ),
                  children: [
                    if (job['result'] is Map)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SelectableText('${job['result']['prompt'] ?? ''}'),
                            for (final option
                                in job['result']['options'] as List? ?? [])
                              Text('• $option'),
                            Text(
                              'Explication : ${job['result']['explanation'] ?? ''}',
                            ),
                            const Text(
                              'La bibliothèque permet de consulter les sources et d’écarter cette question.',
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
