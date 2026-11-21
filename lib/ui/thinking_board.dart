import 'journey_option_order.dart';
import 'retry_feedback.dart';
import 'game_effects.dart';
import 'mystery_photo_hint.dart';
import 'hidden_name_input.dart';
import 'package:flutter/material.dart';
import '../domain/game.dart';
import 'components.dart';
import 'garden_backdrop.dart';
import 'naturalist_guide.dart';
import 'pio.dart';
import 'quest_materials.dart';
import 'bird_photo.dart';
import 'field_choice.dart';
import 'ranking_choice.dart';

/// Shared by the saved journey and free play; all mutations are callbacks.
class ThinkingBoard extends StatelessWidget {
  final Question question;
  final VoidCallback? onModerate;
  final Future<bool> Function()? beforeHint, beforeSpellingHelp;
  final Map<String, dynamic>? feedback;
  final int hints, step, total, score, companionLevel;
  final bool busy, practice;
  final String? error;
  final String? missionTitle, funFact;
  final VoidCallback? onFunFactSource;
  final Map<String, dynamic>? birdMedia;
  final ValueChanged<int> onAnswer;
  final VoidCallback onHint, onNext, onPause, onSource;
  final VoidCallback? onReport;
  const ThinkingBoard({
    this.onReport,
    super.key,
    this.onModerate,
    this.beforeHint,
    this.beforeSpellingHelp,
    required this.question,
    required this.feedback,
    required this.hints,
    required this.step,
    required this.total,
    required this.score,
    required this.companionLevel,
    required this.busy,
    required this.onAnswer,
    required this.onHint,
    required this.onNext,
    required this.onPause,
    required this.onSource,
    this.practice = false,
    this.error,
    this.missionTitle,
    this.funFact,
    this.onFunFactSource,
    this.birdMedia,
  });
  @override
  Widget build(BuildContext context) {
    final mystery = question.kind == 'mystery';
    final locked = busy || feedback != null;
    final ranking = question.data['format'] == 'ranking';
    final placement =
        !mystery &&
        birdMedia != null &&
        const [
          'Où est mon nid ?',
          'Où me trouver ?',
          'À table !',
        ].contains(missionTitle);
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: practice ? 'Quitter le jeu' : 'Mettre la balade en pause',
            onPressed: busy ? null : onPause,
            icon: const Icon(Icons.close),
          ),
          title: Text(
            '${practice ? 'JEU LIBRE' : 'MA BALADE'} · $step/$total',
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            if (onReport != null)
              IconButton(
                tooltip: 'Signaler cette question',
                icon: const Icon(Icons.feedback_outlined),
                onPressed: busy ? null : onReport,
              ),
            if (onModerate != null)
              IconButton(
                tooltip: 'Écarter cette question',
                onPressed: busy ? null : onModerate,
                icon: const Icon(Icons.flag_outlined),
              ),
            if (!practice)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Center(child: Text('$score plumes')),
              ),
          ],
        ),
        body: GameEffects(
          event: feedback == null
              ? null
              : '${question.id}:${feedback!['choice']}',
          success: feedback?['correct'] == true,
          child: GardenBackdrop(
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      LinearProgressIndicator(
                        value: step / total,
                        semanticsLabel: 'Défi $step sur $total',
                      ),
                      SizedBox(height: mystery ? 8 : 16),
                      FieldPaper(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Pio(level: companionLevel, size: 46),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    (ranking
                                            ? 'Le podium des oiseaux'
                                            : missionTitle) ??
                                        (mystery
                                            ? 'L’oiseau mystère'
                                            : 'Le petit quiz'),
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      color: ink,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: mystery ? 8 : 16),
                            if (birdMedia != null &&
                                (!mystery || feedback != null)) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: BirdPhoto(
                                  species: question.species,
                                  media: birdMedia,
                                  height: 210,
                                  semanticLabel: 'L’oiseau de ta mission',
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: onSource,
                                child: const Text('Source et crédit photo'),
                              ),
                              const SizedBox(height: 8),
                            ],
                            Text(
                              mystery ? 'Qui suis-je ?' : question.prompt,
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                                color: ink,
                              ),
                            ),
                            if (mystery) ...[
                              SizedBox(height: mystery ? 8 : 16),
                              for (
                                var i = 0;
                                i < hints.clamp(0, question.clues.length);
                                i++
                              )
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Text(
                                    question.clues[i],
                                    style: const TextStyle(
                                      fontSize: 17,
                                      height: 1.4,
                                      color: ink,
                                    ),
                                  ),
                                ),
                              if (hints < question.clues.length &&
                                  feedback == null)
                                OutlinedButton.icon(
                                  onPressed: busy ? null : onHint,
                                  icon: const Icon(Icons.lightbulb_outline),
                                  label: Text(
                                    practice
                                        ? 'Un indice de plus'
                                        : 'Un indice de plus · ${reward(true, hints + 1)} plumes possibles',
                                  ),
                                ),
                              if (feedback == null)
                                HiddenNameInput(
                                  key: ValueKey(question.id),
                                  question: question,
                                  locked: locked,
                                  beforeHint: beforeHint,
                                  beforeSpellingHelp: beforeSpellingHelp,
                                  photoHint: MysteryPhotoHint(
                                    key: ValueKey('photo-hint-${question.id}'),
                                    species: question.species,
                                    photo: birdMedia,
                                    busy: busy,
                                    beforeHint: beforeHint,
                                    onSource: onSource,
                                  ),
                                  onAnswer: onAnswer,
                                ),
                            ],
                            SizedBox(height: mystery ? 8 : 16),
                            if (!mystery && !placement)
                              NaturalistGuideButton(
                                beforeHint: beforeHint,
                                question: question,
                                answered: feedback != null,
                                enabled: !busy,
                              ),
                            SizedBox(height: mystery ? 8 : 16),
                            if (ranking && feedback == null)
                              RankingChoice(
                                key: ValueKey(question.id),
                                question: question,
                                locked: locked,
                                onAnswer: onAnswer,
                              ),
                            if (ranking && feedback != null)
                              Text(
                                'Le bon ordre : ${question.options[feedback!['answer'] as int]}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            if (placement && feedback == null)
                              FieldChoice(
                                key: ValueKey(question.id),
                                options: question.options,
                                locked: locked,
                                onAnswer: onAnswer,
                              ),
                            if (mystery && feedback != null)
                              Text(
                                question.options[feedback!['answer'] as int],
                                key: const ValueKey('mystery-revealed-name'),
                                style: const TextStyle(
                                  fontSize: 25,
                                  fontWeight: FontWeight.w900,
                                  color: ink,
                                ),
                              ),
                            if (!ranking &&
                                !mystery &&
                                !placement &&
                                feedback == null)
                              for (final i in JourneyOptionOrder.indices(context, question.options.length))
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: RetryChoice(
                                    index: i,
                                    child: QuestButton(
                                      pastelColor: gameButter,
                                      gold: feedback?['answer'] == i,
                                      wrong:
                                          feedback != null &&
                                          feedback!['choice'] == i &&
                                          feedback!['answer'] != i,
                                      onPressed: locked
                                          ? null
                                          : () => onAnswer(i),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              question.options[i],
                                              style: TextStyle(
                                                fontSize: 17,
                                                fontWeight: FontWeight.w800,
                                                color: ink,
                                              ),
                                            ),
                                          ),
                                          if (feedback?['answer'] == i)
                                            const Icon(
                                              Icons.check_circle,
                                              color: green,
                                            ),
                                          if (feedback != null &&
                                              feedback!['choice'] == i &&
                                              feedback!['answer'] != i)
                                            const Icon(
                                              Icons.close,
                                              color: Colors.white,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            if (!ranking && !mystery && feedback != null)
                              Container(
                                key: const ValueKey('revealed-correct-answer'),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xffdceee5),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: const Color(0xff96bdac),
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.check_circle_outline,
                                      color: green,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        question.options[feedback!['answer']
                                            as int],
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w700,
                                          color: ink,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (error != null)
                              Text(
                                error!,
                                style: const TextStyle(
                                  color: Colors.deepOrange,
                                ),
                              ),
                            if (feedback != null) ...[
                              const SizedBox(height: 12),
                              Semantics(
                                liveRegion: true,
                                child: Text(
                                  feedback!['correct'] == true
                                      ? practice
                                            ? 'Bien observé !'
                                            : 'Bien observé ! +${feedback!['points']} plumes'
                                      : 'Un nouvel indice à retenir',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: ink,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (!mystery)
                                Text(
                                  question.explanation,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    height: 1.4,
                                    color: ink,
                                  ),
                                ),
                              if (!mystery)
                                TextButton(
                                  onPressed: onSource,
                                  child: const Text(
                                    'Voir la source scientifique',
                                  ),
                                ),
                              if (mystery && funFact != null)
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xfffff2d4),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Le savais-tu ?',
                                        style: TextStyle(
                                          fontSize: 19,
                                          fontWeight: FontWeight.w800,
                                          color: ink,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        funFact!,
                                        style: const TextStyle(
                                          fontSize: 17,
                                          height: 1.4,
                                          color: ink,
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: onFunFactSource,
                                        child: const Text('Voir la source'),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        bottomNavigationBar: feedback == null
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton(
                    onPressed: busy ? null : onNext,
                    child: Text(
                      busy
                          ? 'Sauvegarde…'
                          : step == total
                          ? practice
                                ? 'Terminer le jeu'
                                : 'Découvrir mon bilan'
                          : 'Continuer →',
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
