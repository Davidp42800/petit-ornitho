import 'package:flutter/material.dart';
import '../data/game_store.dart';
import '../domain/game.dart';
import '../domain/practice_replay.dart';
import '../domain/learning.dart';
import 'quest_board.dart';
import 'journey_option_order.dart';
import 'picture_choice_board.dart';
import 'thinking_board.dart';
import 'components.dart';
import 'garden_backdrop.dart';
import 'quest_materials.dart';
import 'pio.dart';

/// Practice records learning evidence without granting XP or replacing a journey.
class PracticeScreen extends StatefulWidget {
  final GameStore store;
  final String kind;
  const PracticeScreen({super.key, required this.store, required this.kind});
  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  int index = 0, hints = 1, correct = 0;
  int? selected;
  bool finished = false, saving = false;
  String attemptId = newAttemptId();
  DateTime startedAt = DateTime.now();
  Map<String, dynamic>? feedback;
  late List<Question> questions = drawRound();
  List<Question> drawRound() => widget.kind == 'image_choice'
      ? widget.store.imageChoiceRound()
      : widget.kind == 'photo'
      ? widget.store.photoRound()
      : widget.kind == 'quiz'
      ? widget.store.learningRound()
      : widget.store.practiceQuestions
            .where((q) => q.kind == widget.kind)
            .toList();
  Future<void> answer(int choice) async {
    if (feedback != null || finished || saving) return;
    final success = choice == questions[index].answer;
    setState(() {
      saving = true;
      if (success) correct++;
      feedback = {
        'choice': choice,
        'answer': questions[index].answer,
        'correct': success,
        'points': 0,
      };
    });
    try {
      await widget.store.recordPractice(
        questions[index],
        choice,
        attemptId,
        DateTime.now().difference(startedAt).inMilliseconds,
        assisted: hints > 1 || questions[index].data['_hint_used'] == true,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'La sauvegarde attend une nouvelle tentative de connexion.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void next() {
    if (feedback == null || saving) return;
    setState(() {
      if (index + 1 == questions.length) {
        finished = true;
        return;
      }
      index++;
      attemptId = newAttemptId();
      startedAt = DateTime.now();
      hints = 1;
      selected = null;
      feedback = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Jeux')),
        body: const Center(
          child: Text('Ce jeu se prépare. Choisis un autre jeu.'),
        ),
      );
    }
    if (finished) {
      return Scaffold(
        appBar: AppBar(title: const Text('Bravo, partie terminée !')),
        body: GardenBackdrop(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: FieldPaper(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Pio(level: widget.store.unlocked, size: 150),
                      Text(
                        '$correct / ${questions.length} bonnes réponses',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: ink,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Tu t’es entraîné avec Pépi ! Les balades te permettent de gagner des plumes et de le faire grandir.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: () => setState(() {
                          final previous = questions;
                          questions = drawRound()..shuffle();
                          varyReplayOpening(questions, (q) => q.species,
                              previous.first.species, previous.last.species);
                          index = 0;
                          attemptId = newAttemptId();
                          startedAt = DateTime.now();
                          hints = 1;
                          correct = 0;
                          selected = null;
                          feedback = null;
                          finished = false;
                        }),
                        child: const Text('Rejouer'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Retour aux jeux'),
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
    return JourneyOptionOrder(seed: attemptId, child: buildBoard(context));
  }

  Widget buildBoard(BuildContext context) {
    final q = questions[index];
    void source() => sourceDialog(
      context,
      q.data['source'],
      q.data['publisher'],
      q.data['photo'] ??
          widget.store.media.firstWhere(
            (m) => m['id'] == q.species,
            orElse: () => null,
          ),
    );
    if (q.data['image_options'] != null) {
      return PictureChoiceBoard(
        question: q,
        feedback: feedback,
        busy: saving,
        step: index + 1,
        total: questions.length,
        onAnswer: answer,
        onNext: next,
      );
    }
    if (q.kind == 'quiz' || q.kind == 'mystery') {
      return ThinkingBoard(
        question: q,
        feedback: feedback,
        hints: hints,
        step: index + 1,
        total: questions.length,
        score: 0,
        companionLevel: widget.store.unlocked,
        busy: saving,
        practice: true,
        onAnswer: answer,
        onHint: () {
          if (feedback == null && hints < q.clues.length) {
            setState(() => hints++);
          }
        },
        onNext: next,
        onPause: () => Navigator.pop(context),
        onSource: source,
      );
    }
    return QuestBoard(
      practice: true,
      companionLevel: widget.store.unlocked,
      question: q,
      species: widget.store.species,
      selected: selected,
      feedback: feedback,
      busy: saving,
      error: null,
      step: index + 1,
      total: questions.length,
      score: 0,
      onSelect: (value) =>
          q.kind == 'photo' ? answer(value) : setState(() => selected = value),
      onConfirm: () {
        if (selected != null) answer(selected!);
      },
      onNext: next,
      onPause: () => Navigator.pop(context),
      onSource: source,
    );
  }
}
