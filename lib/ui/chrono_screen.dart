import 'quest_materials.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../data/game_store.dart';
import '../domain/game.dart';
import '../domain/learning.dart';
import 'bird_photo.dart';
import 'components.dart';
import 'game_effects.dart';
import 'pio.dart';

/// No network/LLM calls during the timed round. Evidence syncs after the result.
class ChronoScreen extends StatefulWidget {
  final GameStore store;
  final DateTime Function()? clock;
  const ChronoScreen({super.key, required this.store, this.clock});
  @override
  State<ChronoScreen> createState() => _ChronoScreenState();
}

class _ChronoScreenState extends State<ChronoScreen>
    with WidgetsBindingObserver {
  final random = Random();
  Timer? timer;
  DateTime? deadline, shownAt;
  Question? question;
  List<Question> queue = [];
  final answers = <Map<String, dynamic>>[];
  bool started = false, finished = false, locked = false, saving = false;
  bool? lastCorrect;
  int remaining = 60, score = 0, previousBest = 0;
  String? saveError;
  late final owner = widget.store.identity;
  DateTime get now => widget.clock?.call() ?? DateTime.now();
  String get recordKey => widget.store.speciesCatalog.isEmpty
      ? 'ornitho_chrono_photo_v1_$owner'
      : 'ornitho_chrono_photo_v3_${owner}_stage${widget.store.unlocked}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    previousBest = widget.store.prefs.getInt(recordKey) ?? 0;
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The deadline keeps running in the background: no extra time on resume.
    if (state == AppLifecycleState.resumed) tick();
  }

  void chooseNext() {
    if (queue.isEmpty) {
      queue = widget.store.chronoRound(random, question?.species);
    }
    if (queue.isEmpty) {
      finish();
      return;
    }
    question = queue.removeAt(0);
    shownAt = now;
  }

  void start() {
    if (widget.store.identity != owner) return;
    timer?.cancel();
    setState(() {
      started = true;
      finished = false;
      locked = false;
      lastCorrect = null;
      remaining = 60;
      score = 0;
      answers.clear();
      queue.clear();
      saveError = null;
      deadline = now.add(const Duration(seconds: 60));
      chooseNext();
    });
    timer = Timer.periodic(const Duration(milliseconds: 100), (_) => tick());
  }

  void tick() {
    if (!started || finished || !mounted) return;
    if (widget.store.identity != owner) {
      finish();
      return;
    }
    final ms = deadline!.difference(now).inMilliseconds;
    if (ms <= 0) {
      finish();
      return;
    }
    final seconds = (ms / 1000).ceil();
    if (seconds != remaining) setState(() => remaining = seconds);
  }

  Future<void> answer(int choice) async {
    if (locked || finished || question == null) return;
    if (!now.isBefore(deadline!)) {
      finish();
      return;
    }
    final q = question!;
    final correct = choice == q.answer;
    answers.add({
      'question': q,
      'choice': choice,
      'id': newAttemptId(),
      'response_ms': now.difference(shownAt!).inMilliseconds,
    });
    setState(() {
      locked = true;
      lastCorrect = correct;
      if (correct) {
        score++;
      } else {
        deadline = deadline!.subtract(const Duration(seconds: 3));
      }
    });
    tick();
    // Tiny feedback beat; taps cannot answer the following photo accidentally.
    await Future<void>.delayed(const Duration(milliseconds: 260));
    if (!mounted || finished) return;
    setState(() {
      chooseNext();
      locked = false;
    });
  }

  void finish() {
    if (finished) return;
    timer?.cancel();
    setState(() {
      finished = true;
      remaining = 0;
      locked = true;
    });
    unawaited(saveResult());
  }

  Future<void> saveResult() async {
    if (saving || widget.store.identity != owner) return;
    setState(() {
      saving = true;
      saveError = null;
    });
    try {
      final best = max(score, widget.store.prefs.getInt(recordKey) ?? 0);
      if (!await widget.store.prefs.setInt(recordKey, best)) {
        throw StateError('Record non sauvegardé');
      }
      // Stable attempt IDs allow retry without double-counting learning evidence.
      for (final a in answers) {
        if (widget.store.identity != owner) return;
        await widget.store.recordPractice(
          a['question'],
          a['choice'],
          a['id'],
          a['response_ms'],
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => saveError =
              'La sauvegarde n’est pas terminée. Tu peux réessayer.',
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final errors = answers
        .where((a) => a['choice'] != (a['question'] as Question).answer)
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Série chrono')),
      body: GameEffects(
        event: answers.isEmpty ? null : answers.length,
        success: lastCorrect ?? false,
        child: GamePageBody(
          children: [
            if (!started) ...[
              const Pio(size: 130),
              const Text(
                '60 secondes avec Pépi !',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: ink,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Trouve le plus d’oiseaux possible. Une bonne réponse = 1 point. Une erreur enlève 3 secondes.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Ton record photo : $previousBest',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: start,
                child: const Text('Démarrer · Photos'),
              ),
              const SizedBox(height: 12),
              const Text(
                'Le chrono au chant arrivera après la vérification des enregistrements.',
                textAlign: TextAlign.center,
              ),
            ] else if (finished) ...[
              const Pio(size: 100),
              Text(
                '$score ${score == 1 ? 'oiseau reconnu' : 'oiseaux reconnus'} !',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: ink,
                ),
              ),
              Text(
                score > previousBest
                    ? 'Nouveau record personnel !'
                    : 'Ton record : $previousBest',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                errors.isEmpty
                    ? 'Bravo pour cette exploration !'
                    : 'On observe ensemble tes ${errors.length} erreurs ?',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              for (final a in errors) _errorCard(a),
              if (saving)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Sauvegarde des découvertes…'),
                ),
              if (saveError != null) ...[
                Text(saveError!),
                TextButton(
                  onPressed: saving ? null : saveResult,
                  child: const Text('Réessayer la sauvegarde'),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: saving ? null : start,
                child: const Text('Rejouer'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Retour aux jeux'),
              ),
            ] else if (question != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$remaining s',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: ink,
                    ),
                  ),
                  Text(
                    '$score ${score == 1 ? 'point' : 'points'}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: ink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: remaining / 60),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: BirdPhoto(
                  species: question!.species,
                  media: question!.data['photo'],
                  height: 220,
                ),
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < question!.options.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: gameButter,
                      foregroundColor: ink,
                      minimumSize: const Size(double.infinity, 52),
                    ),
                    onPressed: locked ? null : () => answer(i),
                    child: Text(question!.options[i]),
                  ),
                ),
              if (lastCorrect != null)
                Text(
                  lastCorrect! ? 'Bien vu !' : 'Pas celui-ci : −3 secondes',
                  textAlign: TextAlign.center,
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _errorCard(Map<String, dynamic> a) {
    final q = a['question'] as Question;
    final chosen = q.data['option_species']?[a['choice']];
    final comparison =
        (widget.store.learningRules['comparisons'] as List? ?? [])
            .where(
              (c) =>
                  c['status'] == 'published' &&
                  c['modality'] == 'visual' &&
                  {
                    c['species_a'],
                    c['species_b'],
                  }.containsAll([q.species, chosen]),
            )
            .firstOrNull;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${q.options[a['choice']]} → ${q.options[q.answer]}',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            BirdPhoto(species: q.species, media: q.data['photo'], height: 160),
            const SizedBox(height: 10),
            Text(
              comparison == null
                  ? 'À observer sur cette photo'
                  : 'Le détail qui les distingue',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(comparison?['message'] ?? q.data['hint'] ?? q.explanation),
            if (comparison != null)
              for (final source in comparison['sources'])
                TextButton(
                  onPressed: () => sourceDialog(
                    context,
                    source['url'],
                    'Station ornithologique suisse',
                    null,
                  ),
                  child: Text('Fiche : ${source['title']}'),
                ),
            TextButton(
              onPressed: () => sourceDialog(
                context,
                q.data['source'],
                q.data['publisher'],
                q.data['photo'],
              ),
              child: const Text('Voir les sources et la photo'),
            ),
          ],
        ),
      ),
    );
  }
}
