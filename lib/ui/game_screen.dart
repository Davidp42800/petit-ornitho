import 'journey_option_order.dart';
import 'content_report.dart';
import '../domain/decisive_criterion.dart';
import 'criterion_board.dart';
import 'retry_feedback.dart';
import 'game_effects.dart';
import 'audio_mission.dart';
import 'picture_choice_board.dart';
import '../domain/bird_recording.dart';
import 'package:flutter/material.dart';
import '../data/game_store.dart';
import 'components.dart';
import 'quest_board.dart';
import 'thinking_board.dart';
import 'package:flutter/services.dart';
import 'result_screen.dart';

class GameScreen extends StatefulWidget {
  final GameStore store;
  const GameScreen({super.key, required this.store});
  @override
  State<GameScreen> createState() => _GameState();
}

class _GameState extends State<GameScreen> {
  String? recoveredQuestion;
  Set<int> wrongChoices = {};
  int celebration = 0;
  void celebrateAnswer() {
    celebration++;
    // The bird card stays open until the player chooses Suivant.
  }

  bool busy = false;
  bool ornithoAdmin = false;
  bool recovering = false;
  String? recoveryError;
  String? attemptedRecovery;
  @override
  void initState() {
    super.initState();
    checkAdmin();
  }

  Future<void> recoverQuestions() async {
    if (recovering) return;
    setState(() {
      recovering = true;
      recoveryError = null;
    });
    try {
      await s.fetchJourneyQuestions();
      if (s.currentOrNull == null) throw StateError('Question unavailable');
    } catch (_) {
      if (mounted) {
        recoveryError =
            'La question n’a pas pu être chargée. Vérifie ta connexion et réessaie.';
      }
    } finally {
      if (mounted) setState(() => recovering = false);
    }
  }

  Future<void> checkAdmin() async {
    if (!s.cloud) return;
    try {
      final allowed = await s.client.rpc('is_ornitho_admin');
      if (mounted) setState(() => ornithoAdmin = allowed == true);
    } catch (_) {
      // No moderation controls without a confirmed server role.
    }
  }

  Future<void> moderate() async {
    final question = s.current;
    final note = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Écarter cette question'),
        content: TextField(
          controller: note,
          maxLength: 2000,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Erreur ou ambiguïté constatée',
            helperText: 'Au moins 10 caractères.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              if (note.text.trim().length >= 10) {
                Navigator.pop(ctx, note.text.trim());
              }
            },
            child: const Text('Écarter des prochaines balades'),
          ),
        ],
      ),
    );
    note.dispose();
    if (reason == null || !mounted) return;
    await action(() async {
      if (question.data['fact_id'] == null) {
        await s.client.rpc(
          'retire_media_question',
          params: {
            'p_id': question.id,
            'p_version': question.data['version'] ?? 1,
            'p_note': reason,
          },
        );
      } else {
        final detail = await s.client.rpc(
          'editorial_catalogue',
          params: {'p_species': question.species},
        );
        final row = (detail['questions'] as List).firstWhere(
          (q) =>
              q['id'] == question.id &&
              q['version'] == (question.data['version'] ?? 1),
        );
        await s.client.rpc(
          'review_learning_question',
          params: {
            'p_id': question.id,
            'p_version': row['version'],
            'p_revision': row['revision'],
            'p_decision': 'reject',
            'p_note': reason,
            'p_checked': true,
          },
        );
      }
      await s.syncQuestionWithdrawals();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Question écartée des prochaines balades.'),
          ),
        );
      }
    });
  }

  String? error;
  int? matchSelection;
  GameStore get s => widget.store;

  Future<void> action(Future<void> Function() task) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await task();
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'La réponse n’a pas pu être enregistrée. Réessaie : elle ne sera comptée qu’une fois.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<bool> registerHint() async {
    if (busy) return false;
    var registered = false;
    await action(() async {
      await s.registerGuideHint();
      registered = true;
    });
    return registered;
  }

  Future<bool> registerSpellingHelp() async {
    if (busy) return false;
    var registered = false;
    await action(() async {
      await s.registerSpellingHelp();
      registered = true;
    });
    return registered;
  }

  Future<void> restartSeries() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Recommencer cette série ?'),
        content: const Text(
          'Les réponses et les points de cette série en cours ne seront pas validés. Tes balades terminées et tes niveaux sont conservés.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Recommencer'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await action(() async {
        await s.restartJourney();
      });
    }
  }

  Future<void> answer(int v) => action(() async {
    final q = s.current;
    final existing = s.active?['feedback'];
    if (q.kind != 'audio' && existing != null) {
      if (existing['correct'] == true ||
          recoveredQuestion == q.id ||
          wrongChoices.contains(v)) {
        return;
      }
      if (v == existing['answer']) {
        recoveredQuestion = q.id;
        celebrateAnswer();
      } else {
        wrongChoices = {...wrongChoices, v};
      }
    } else {
      await s.answer(v);
      if (!mounted) return;
      if (q.kind != 'audio') {
        if (s.active?['feedback']?['correct'] == true) {
          celebrateAnswer();
        } else {
          wrongChoices = {...wrongChoices, v};
        }
      }
    }
    if (!mounted) return;
    HapticFeedback.lightImpact();
    setState(() {});
  });
  Future<void> next() => action(() async {
    final previousLevel = s.unlocked;
    final result = await s.next();
    if (!mounted) return;
    matchSelection = null;
    recoveredQuestion = null;
    wrongChoices = {};
    if (result != null) {
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            result: {
              ...result,
              'audio_available': s.audioAvailableInStage(result['level']),
            },
            companionLevel: s.unlocked,
            companionGrew: s.unlocked > previousLevel,
          ),
        ),
      );
    } else {
      setState(() {});
    }
  });
  @override
  Widget build(BuildContext context) {
    final first = s.active?['feedback'];
    final wrong = {
      ...wrongChoices,
      if (first?['correct'] == false) first['choice'] as int,
    };
    final session = s.active;
    return JourneyOptionOrder(
      seed: "${session?['id']}/${session?['index']}",
      child: RetryFeedback(
        wrong: wrong,
        correctAnswer: first?['answer'] as int?,
        child: Builder(
          builder: (context) {
            final board = buildBoard(context);
            // These boards already celebrate their own answer. Keep a single
            // banner rather than painting a second celebration over the first.
            if (board is QuestBoard ||
                board is ThinkingBoard ||
                board is AudioMission) {
              return board;
            }
            return GameEffects(
              event: celebration == 0 ? null : celebration,
              success: true,
              child: board,
            );
          },
        ),
      ),
    );
  }

  Widget buildBoard(BuildContext context) {
    final a = s.active;
    if (a == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ta balade')),
        body: Center(
          child: FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Retour au parcours'),
          ),
        ),
      );
    }
    final q = s.currentOrNull;
    if (q == null) {
      final recoveryKey = '${a['id']}:${a['index']}';
      if (s.cloud && attemptedRecovery != recoveryKey) {
        attemptedRecovery = recoveryKey;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) recoverQuestions();
        });
      }
      return Scaffold(
        appBar: AppBar(title: const Text('Ta balade est sauvegardée')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (recovering) const CircularProgressIndicator(),
                Text(
                  recoveryError ??
                      'Chargement de ta question… Ta progression est conservée.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                if (s.cloud && !recovering)
                  FilledButton(
                    onPressed: recoverQuestions,
                    child: const Text('Réessayer'),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Retour au parcours'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    void report() => reportContent(
      context,
      s,
      speciesId: q.species,
      questionId: q.id,
      photo: q.data['photo'] is Map ? q.data['photo']['asset'] as String? : null,
      version: q.data['version'] as int?,
    );
    if (q.data['format'] == 'decisive_criterion') {
      final progress = a['criterion'] == null
          ? DecisiveCriterion.start(q.data)
          : DecisiveCriterion.restore(
              q.data,
              Map<String, dynamic>.from(a['criterion']),
            );
      final factIds = Set<String>.from(q.data['fact_ids'] ?? const []);
      return CriterionBoard(
        onReport: report,
        question: q,
        progress: progress,
        facts: (s.publishedFacts ?? const [])
            .where(
              (f) =>
                  factIds.contains(f['id']) &&
                  f['source_url'] is String &&
                  f['publisher'] is String,
            )
            .map((f) => Map<String, dynamic>.from(f))
            .toList(),
        feedback: a['feedback'] == null
            ? null
            : Map<String, dynamic>.from(a['feedback']),
        busy: busy,
        error: error,
        step: a['index'] + 1,
        total: (a['ids'] as List).length,
        score: a['score'],
        onPause: () => Navigator.pop(context),
        onNext: next,
        onAnswer: (phase, choice) => action(() async {
          final result = await s.answerCriterion(phase, choice);
          if (!mounted) return;
          if (result.phase(q.data) == null) celebrateAnswer();
          HapticFeedback.lightImpact();
          setState(() {});
        }),
      );
    }
    final storedFeedback = a['feedback'];
    final feedback = q.kind == 'audio' || storedFeedback?['correct'] == true
        ? storedFeedback
        : recoveredQuestion == q.id
        ? {
            ...Map<String, dynamic>.from(storedFeedback),
            'correct': true,
            'points': 0,
          }
        : null;
    final hints = a['hints'] as int;
    if (q.data['format'] == 'image_choice') {
      return PictureChoiceBoard(
        onReport: report,
        question: q,
        feedback: feedback == null ? null : Map<String, dynamic>.from(feedback),
        busy: busy,
        step: a['index'] + 1,
        total: (a['ids'] as List).length,
        onAnswer: answer,
        onNext: next,
        onPause: () => Navigator.pop(context),
        error: error,
        beforeHint: registerHint,
        onModerate: ornithoAdmin ? moderate : null,
      );
    }
    if (q.kind == 'audio') {
      final clips = BirdRecording.validated([q.data['recording']], s.species);
      if (clips.isEmpty) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Son indisponible'),
            actions: [
              IconButton(
                tooltip: 'Signaler cette question',
                icon: const Icon(Icons.feedback_outlined),
                onPressed: report,
              ),
            ],
          ),
          body: const Center(
            child: Text(
              'Cet extrait doit être vérifié. Ta progression est conservée.',
            ),
          ),
        );
      }
      return AudioMission(
        onReport: report,
        level: a['level'] as int? ?? 1,
        onRestart: restartSeries,
        onModerate: ornithoAdmin ? moderate : null,
        key: ValueKey('${a['id']}:${a['index']}'),
        question: q,
        recording: clips.single,
        saveError: error,
        feedback: feedback,
        busy: busy,
        step: a['index'] + 1,
        total: (a['ids'] as List).length,
        onAnswer: answer,
        onNext: next,
        onPause: () => Navigator.pop(context),
        beforeHint: registerHint,
      );
    }
    if (q.kind == 'match' || q.kind == 'photo') {
      return QuestBoard(
        onReport: report,
        journeyName: s.stagePlace(a['level'] as int),
        beforeHint: registerHint,
        question: q,
        onModerate:
            ornithoAdmin &&
                (q.data['fact_id'] != null ||
                    q.kind == 'photo' ||
                    q.kind == 'audio')
            ? moderate
            : null,
        companionLevel: s.unlocked,
        species: s.species,
        selected: matchSelection,
        feedback: feedback,
        busy: busy,
        error: error,
        step: a['index'] + 1,
        total: (a['ids'] as List).length,
        score: a['score'],
        onSelect: (value) {
          HapticFeedback.selectionClick();
          if (q.kind == 'photo') {
            answer(value);
          } else {
            setState(() => matchSelection = value);
          }
        },
        onConfirm: () => answer(matchSelection!),
        onNext: next,
        onPause: () => Navigator.pop(context),
        onSource: () => sourceDialog(
          context,
          q.data['source'],
          q.data['publisher'],
          s.media.firstWhere((m) => m['id'] == q.species, orElse: () => null),
        ),
      );
    }
    final fact = s
        .sourcedFactsFor(q.species)
        .where((f) => f['id'] == q.data['fact_id'])
        .firstOrNull;
    final missionTitle = switch (fact?['topic']) {
      'breeding' =>
        RegExp(
              r'où|quel.*(endroit|abri|lieu|emplacement|site)|dans quoi',
              caseSensitive: false,
            ).hasMatch(q.prompt)
            ? 'Où est mon nid ?'
            : 'La vie de famille',
      'habitat' => 'Où me trouver ?',
      'diet' => 'À table !',
      'migration' => 'Voyageur ou voisin ?',
      'behaviour' => 'Que fais-tu, petit oiseau ?',
      _ => null,
    };
    final missionPhoto = q.data['format'] == 'ranking'
        ? null
        : s.photoFor(q.species);
    final usedFacts = {q.data['fact_id'], ...?q.data['fact_ids'] as List?};
    final bonusFacts = s
        .sourcedFactsFor(q.species)
        .where(
          (f) =>
              !usedFacts.contains(f['id']) &&
              const ['behaviour', 'breeding', 'diet'].contains(f['topic']) &&
              f['statement'] != q.explanation &&
              !q.clues.contains(f['statement']) &&
              f['source_url'] != null,
        )
        .toList();
    bonusFacts.sort(
      (a, b) => (a['topic'] == 'behaviour' ? 0 : 1).compareTo(
        b['topic'] == 'behaviour' ? 0 : 1,
      ),
    );
    final funFact = bonusFacts.firstOrNull;
    return ThinkingBoard(
      onReport: report,
      funFact: funFact?['statement'] as String?,
      onFunFactSource: funFact == null
          ? null
          : () => sourceDialog(
              context,
              funFact['source_url'],
              funFact['publisher'],
              null,
            ),
      beforeSpellingHelp: registerSpellingHelp,
      beforeHint: registerHint,
      question: q,
      onModerate:
          ornithoAdmin &&
              (q.data['fact_id'] != null ||
                  q.kind == 'photo' ||
                  q.kind == 'audio')
          ? moderate
          : null,
      missionTitle: missionTitle,
      birdMedia: missionPhoto,
      feedback: feedback == null ? null : Map<String, dynamic>.from(feedback),
      hints: hints,
      step: a['index'] + 1,
      total: (a['ids'] as List).length,
      score: a['score'],
      companionLevel: s.unlocked,
      busy: busy,
      error: error,
      onAnswer: answer,
      onHint: () => action(() async {
        await s.hint();
      }),
      onNext: next,
      onPause: () => Navigator.pop(context),
      onSource: () => sourceDialog(
        context,
        q.data['source'],
        q.data['publisher'],
        missionPhoto,
        additionalSources: q.data['sources'] as List? ?? const [],
        additionalMedia: q.data['ranking_birds'] as List? ?? const [],
      ),
    );
  }
}
