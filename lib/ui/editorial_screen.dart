import 'bird_photo.dart';
import 'content_report_inbox.dart';
import 'question_generation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// All reads and decisions are authorized again by the database.
class EditorialScreen extends StatefulWidget {
  final SupabaseClient client;
  const EditorialScreen({super.key, required this.client});
  @override
  State<EditorialScreen> createState() => _EditorialScreenState();
}

class _EditorialScreenState extends State<EditorialScreen> {
  List<dynamic>? species;
  Map<String, dynamic>? selected, details;
  String? error;
  bool busy = false;
  bool questionLibrary = false;
  String? questionStatus = 'published';
  final questionSearch = TextEditingController();
  List<dynamic> questionRows = [];
  int questionTotal = 0;
  @override
  void dispose() {
    questionSearch.dispose();
    super.dispose();
  }

  Future<void> loadQuestions({bool more = false}) async {
    setState(() {
      busy = true;
      error = null;
      questionLibrary = true;
      if (!more) {
        questionRows = [];
        questionTotal = 0;
      }
    });
    try {
      final result = await widget.client.rpc(
        'editorial_questions',
        params: {
          'p_status': questionStatus,
          'p_search': questionSearch.text.trim(),
          'p_offset': more ? questionRows.length : 0,
        },
      );
      if (!mounted) return;
      setState(() {
        questionRows = [if (more) ...questionRows, ...result['items'] as List];
        questionTotal = result['total'] as int;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Impossible de charger les questions. Réessayez.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load([Map<String, dynamic>? bird]) async {
    setState(() {
      busy = true;
      error = null;
      details = null;
      selected = bird;
    });
    try {
      final value = await widget.client.rpc(
        'editorial_catalogue',
        params: {'p_species': bird?['id']},
      );
      if (!mounted) return;
      setState(() {
        if (bird == null) {
          species = value as List;
        } else {
          details = Map<String, dynamic>.from(value as Map);
        }
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Impossible de charger la relecture. Vérifiez votre connexion et votre rôle Ornitho admin.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> link(String? url) async {
    final uri = Uri.tryParse(url ?? '');
    if (uri == null || uri.scheme != 'https') return;
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('link');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Le lien ne peut pas être ouvert.')),
        );
      }
    }
  }

  Future<void> review(
    String kind,
    Map<String, dynamic> item,
    bool approve,
  ) async {
    final note = TextEditingController();
    final start = TextEditingController(
      text: '${(item['clip_start_ms'] as num? ?? 0) / 1000}',
    );
    final end = TextEditingController(
      text: item['clip_end_ms'] == null
          ? ''
          : '${(item['clip_end_ms'] as num) / 1000}',
    );
    bool checked = false;
    final submitted = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: Text(approve ? 'Approuver ce contenu' : 'Écarter ce contenu'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (kind == 'song' && approve) ...[
                    const Text(
                      'Indiquez l’extrait écouté, de 30 secondes maximum. Seuls les chants identifiés de qualité A ou B sous licence autorisée peuvent être publiés.',
                    ),
                    TextField(
                      controller: start,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Début (secondes)',
                      ),
                    ),
                    TextField(
                      controller: end,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Fin (secondes)',
                      ),
                    ),
                  ],
                  TextField(
                    controller: note,
                    maxLength: 2000,
                    minLines: 3,
                    maxLines: 5,
                    onChanged: (_) => update(() {}),
                    decoration: const InputDecoration(
                      labelText:
                          'Justification de la décision (10 caractères min.)',
                    ),
                  ),
                  CheckboxListTile(
                    value: checked,
                    onChanged: (v) => update(() => checked = v ?? false),
                    title: Text(
                      kind == 'song'
                          ? 'J’ai écouté le son, vérifié l’espèce et la licence.'
                          : kind == 'photo'
                          ? 'J’ai examiné la photo, son identification, son cadrage et sa licence.'
                          : kind == 'question'
                          ? 'J’ai vérifié la source, la bonne réponse, les autres choix et la clarté pour les ornithos en herbe.'
                          : 'J’ai lu la source et vérifié cette affirmation.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: !checked || note.text.trim().length < 10
                  ? null
                  : () {
                      final a = double.tryParse(
                        start.text.replaceAll(',', '.'),
                      );
                      final b = double.tryParse(end.text.replaceAll(',', '.'));
                      if (kind == 'song' &&
                          approve &&
                          (a == null ||
                              b == null ||
                              !a.isFinite ||
                              !b.isFinite ||
                              a < 0 ||
                              b <= a ||
                              b - a > 30)) {
                        return;
                      }
                      Navigator.pop(ctx, {
                        'p_note': note.text.trim(),
                        'p_checked': true,
                        'p_clip_start': a != null && a.isFinite
                            ? (a * 1000).round()
                            : null,
                        'p_clip_end': b != null && b.isFinite
                            ? (b * 1000).round()
                            : null,
                      });
                    },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
    // Controllers remain alive through the dialog's closing transition.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    note.dispose();
    start.dispose();
    end.dispose();
    if (submitted == null || !mounted) return;
    setState(() => busy = true);
    try {
      if (kind == 'question') {
        submitted.remove('p_clip_start');
        submitted.remove('p_clip_end');
      }
      if (item['entry_type'] == 'media') {
        await widget.client.rpc(
          'retire_media_question',
          params: {
            'p_id': item['id'],
            'p_version': item['version'],
            'p_note': submitted['p_note'],
          },
        );
      } else {
        await widget.client.rpc(
          kind == 'question'
              ? 'review_learning_question'
              : 'review_species_item',
          params: {
            ...submitted,
            if (kind == 'question') 'p_version': item['version'],
            if (kind != 'question') 'p_kind': kind,
            'p_id': item['id'],
            'p_revision': item['revision'],
            'p_decision': approve ? 'approve' : 'reject',
          },
        );
      }
      if (mounted) {
        if (questionLibrary) {
          await loadQuestions();
        } else {
          await load(selected);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = e is PostgrestException && e.code == 'P0001'
              ? e.message
              : 'Décision non enregistrée : source, licence, extrait ou droit de validation non conforme. Rechargez la fiche si elle a changé.';
        });
      }
    }
  }

  Future<void> openGeneration([Map<String, dynamic>? seed]) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            QuestionGenerationScreen(client: widget.client, seed: seed),
      ),
    );
    if (mounted && questionLibrary) await loadQuestions();
  }

  Widget itemCard(String kind, Map<String, dynamic> item) {
    final document = item['document'] as Map?;
    final source = item['source'] as Map?;
    final sourceUrl = (kind == 'fact' || kind == 'question')
        ? (source?['url'])
        : item['source_url'];
    final mediaQuestion = item['entry_type'] == 'media';
    final canApprove =
        !mediaQuestion &&
        (kind != 'song' || item['vocalization_kind'] == 'song');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${item['species_name'] ?? item['topic'] ?? item['id']} · ${statusLabel(item['status'])}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (kind == 'fact') ...[
              SelectableText('${item['statement']}'),
              Text(
                '${document?['title'] ?? 'Document manquant'}\nPage : ${item['page'] ?? '—'} · Section : ${item['section'] ?? '—'}\nRepère : ${item['source_locator'] ?? '—'}',
              ),
            ],
            if (kind == 'question') ...[
              Text('Version ${item['version']} · ${item['id']}'),
              SelectableText('${item['prompt']}'),
              for (var i = 0; i < (item['options'] as List).length; i++)
                Text(
                  '${i == item['answer'] ? '✓' : '○'} ${item['options'][i]}',
                ),
              Text(
                'Indice : ${item['hint']}\nExplication : ${item['explanation']}',
              ),
              if (!mediaQuestion)
                Text(
                  'Fait source : ${item['fact']?['statement'] ?? 'Manquant'}\nStatut du fait : ${item['fact']?['status'] ?? 'Manquant'}\nRepère : ${item['fact']?['source_locator'] ?? item['fact']?['page'] ?? 'Manquant'}',
                ),
            ],
            if (mediaQuestion) ...[
              Text(
                item['kind'] == 'audio'
                    ? 'Identification au son'
                    : 'Identification en photo',
              ),
              if (item['photo'] != null)
                BirdPhoto(
                  species: item['species_id'],
                  media: Map<String, dynamic>.from(item['photo']),
                  height: 220,
                ),
              if (item['recording'] != null) ...[
                Text(
                  'Enregistrement : ${item['recording']['author']} · ${item['recording']['license']}',
                ),
                TextButton(
                  onPressed: () => link('${item['recording']['source']}'),
                  child: const Text('Écouter sur Xeno-canto ↗'),
                ),
              ],
              for (final option in item['option_photos'] as List? ?? [])
                BirdPhoto(
                  species: option['species_id'],
                  media: Map<String, dynamic>.from(option['photo']),
                  height: 140,
                ),
            ],
            if (kind == 'question' && item['history'] != null)
              for (final decision in item['history'] as List)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${decision['decision'] == 'reject' ? 'Écartée' : 'Remise en jeu'} · ${decision['reviewer_name']}',
                  ),
                  subtitle: SelectableText(
                    '${decision['reviewed_at']}\n${decision['note']}',
                  ),
                ),
            if (kind == 'photo')
              Image.network(
                '${item['url']}',
                height: 260,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Text(
                  'Photo indisponible : ne pas approuver sans la voir.',
                ),
              ),
            if (kind != 'fact' && kind != 'question')
              Text(
                '${item['scientific_name']}\nAuteur : ${item['author']}\nLicence : ${item['license'] ?? item['license_url']}',
              ),
            if (item['reviewer'] != null)
              Text(
                'Dernière revue : ${item['reviewer']} · ${item['reviewed_at']}',
              ),
            Wrap(
              spacing: 12,
              children: [
                TextButton(
                  onPressed: sourceUrl == null
                      ? null
                      : () => link('$sourceUrl'),
                  child: const Text('Consulter la source'),
                ),
                if (document?['artifact_url'] != null)
                  TextButton(
                    onPressed: () => link('${document!['artifact_url']}'),
                    child: const Text('Document de référence'),
                  ),
                if (kind == 'song')
                  TextButton(
                    onPressed: () => link('${item['audio_url']}'),
                    child: const Text('Écouter l’enregistrement ↗'),
                  ),
              ],
            ),
            if (kind == 'question' &&
                !mediaQuestion &&
                item['status'] == 'published' &&
                !'${item['id']}'.startsWith('llm_') &&
                (item['options'] as List).length >= 3 &&
                (item['options'] as List).length <= 4)
              TextButton.icon(
                onPressed: busy ? null : () => openGeneration(item),
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Créer une scène de terrain'),
              ),
            if (!canApprove && !mediaQuestion)
              const Text(
                'Cri / autre vocalisation : publication non prise en charge par les jeux de chant actuels.',
              ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy || item['status'] == 'retired'
                        ? null
                        : () => review(kind, item, false),
                    child: const Text('Écarter'),
                  ),
                ),
                const SizedBox(width: 12),
                if (!mediaQuestion)
                  Expanded(
                    child: FilledButton(
                      onPressed:
                          busy || !canApprove || item['status'] == 'published'
                          ? null
                          : () => review(kind, item, true),
                      child: Text(
                        kind == 'question' ? 'Remettre en jeu' : 'Approuver',
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Ornitho admin'),
      actions: [
        IconButton(
          tooltip: 'Recharger',
          onPressed: busy
              ? null
              : () => questionLibrary ? loadQuestions() : load(selected),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Bibliothèque ornitho',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Consultez les questions, leurs réponses et leurs sources. Les questions écartées restent conservées avec le motif du retrait.',
            ),
            Wrap(
              spacing: 12,
              children: [
                ChoiceChip(
                  label: const Text('Fiches espèces'),
                  selected: !questionLibrary,
                  onSelected: busy
                      ? null
                      : (_) => setState(() => questionLibrary = false),
                ),
                ChoiceChip(
                  label: const Text('Toutes les questions'),
                  selected: questionLibrary,
                  onSelected: busy ? null : (_) => loadQuestions(),
                ),
              ],
            ),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ContentReportInbox(client: widget.client),
                ),
              ),
              icon: const Icon(Icons.flag_outlined),
              label: const Text('Signalements à vérifier'),
            ),
            TextButton.icon(
              onPressed: busy ? null : () => openGeneration(),
              icon: const Icon(Icons.history),
              label: const Text('Historique des générations IA'),
            ),
            if (questionLibrary) ...[
              TextField(
                controller: questionSearch,
                maxLength: 200,
                decoration: InputDecoration(
                  labelText: 'Rechercher une espèce ou une question',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    tooltip: 'Rechercher',
                    onPressed: busy ? null : () => loadQuestions(),
                  ),
                ),
                onSubmitted: busy ? null : (_) => loadQuestions(),
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final entry in const {
                    'published': 'En jeu',
                    'retired': 'Écartées',
                    'all': 'Tous les statuts',
                  }.entries)
                    ChoiceChip(
                      label: Text(entry.value),
                      selected:
                          questionStatus ==
                          (entry.key == 'all' ? null : entry.key),
                      onSelected: busy
                          ? null
                          : (_) {
                              questionStatus = entry.key == 'all'
                                  ? null
                                  : entry.key;
                              loadQuestions();
                            },
                    ),
                ],
              ),
              Text('${questionRows.length} / $questionTotal questions'),
            ],
            if (busy) const LinearProgressIndicator(),
            if (error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(error!, style: const TextStyle(color: Colors.red)),
              ),
            if (questionLibrary) ...[
              if (!busy && error == null && questionRows.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Aucune question pour cette recherche.'),
                ),
              for (final row in questionRows)
                itemCard('question', Map<String, dynamic>.from(row as Map)),
              if (questionRows.length < questionTotal)
                OutlinedButton(
                  onPressed: busy ? null : () => loadQuestions(more: true),
                  child: const Text('Afficher les suivantes'),
                ),
            ] else if (selected != null) ...[
              TextButton(
                onPressed: busy ? null : () => load(),
                child: const Text('← Toutes les espèces'),
              ),
              Text(
                '${selected!['name']} — ${selected!['latin']}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (details != null) ...[
                for (final group in const [
                  ('facts', 'fact', 'Descriptions sourcées'),
                  ('photos', 'photo', 'Photos'),
                  ('songs', 'song', 'Chants'),
                  ('questions', 'question', 'Questions à jouer'),
                ]) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      '${group.$3} (${(details![group.$1] as List).length})',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if ((details![group.$1] as List).isEmpty)
                    const Text('Aucun contenu enregistré pour cette rubrique.'),
                  for (final row in details![group.$1] as List)
                    itemCard(group.$2, Map<String, dynamic>.from(row as Map)),
                ],
                const Text(
                  'Historique des décisions',
                  style: TextStyle(fontSize: 22),
                ),
                for (final h in details!['history'] as List)
                  ListTile(
                    title: Text(
                      '${h['kind']} · ${h['item_id']} · ${h['decision']}',
                    ),
                    subtitle: Text(
                      '${h['reviewer_name']} · ${h['reviewed_at']}\n${h['note']}',
                    ),
                  ),
              ],
            ] else if (species != null)
              for (final row in species!)
                ListTile(
                  title: Text('Niveau ${row['level_id']} · ${row['name']}'),
                  subtitle: Text(
                    '${row['latin']} · ${row['facts']} faits · ${row['photos']} photos · ${row['songs']} sons (candidats inclus)',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: busy
                      ? null
                      : () => load(Map<String, dynamic>.from(row as Map)),
                ),
          ],
        ),
      ),
    ),
  );
}

String statusLabel(dynamic status) => switch (status) {
  'published' => 'En jeu',
  'retired' => 'Écartée',
  'draft' => 'En préparation',
  'candidate' => 'À vérifier',
  _ => '$status',
};
