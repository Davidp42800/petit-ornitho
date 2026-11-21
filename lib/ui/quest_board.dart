import 'journey_option_order.dart';
import 'retry_feedback.dart';
import 'game_effects.dart';
import 'package:flutter/material.dart';
import '../domain/game.dart';
import 'bird_photo.dart';
import 'garden_backdrop.dart';
import 'quest_materials.dart';
import 'naturalist_guide.dart';
import 'pio.dart';

const _ink = Color(0xff284958);
const _sky = Color(0xffe5f0f4);
const _mint = Color(0xffdceee5);
const _peach = Color(0xffffe0d2);
const _butter = gameButter;

const _forest = Color(0xff145b72);
const _gold = Color(0xffe8c778);
const _paper = Color(0xfff6f8f3);

/// Shared adventure setting for photo identification and clue selection.
class QuestBoard extends StatelessWidget {
  final Question question;
  final VoidCallback? onModerate;
  final Future<bool> Function()? beforeHint;
  final List<dynamic> species;
  final int? selected;
  final dynamic feedback;
  final bool busy;
  final bool practice;
  final String? journeyName;
  final String? error;
  final int step, total, score;
  final int companionLevel;
  final ValueChanged<int> onSelect;
  final VoidCallback onConfirm, onNext, onPause, onSource;
  final VoidCallback? onReport;
  const QuestBoard({
    this.onReport,
    super.key,
    this.onModerate,
    this.beforeHint,
    this.practice = false,
    this.journeyName,
    this.companionLevel = 1,
    required this.question,
    required this.species,
    required this.selected,
    required this.feedback,
    required this.busy,
    required this.error,
    required this.step,
    required this.total,
    required this.score,
    required this.onSelect,
    required this.onConfirm,
    required this.onNext,
    required this.onPause,
    required this.onSource,
  });

  bool get photo => question.kind == 'photo';
  bool get locked => busy || feedback != null;
  Duration duration(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : const Duration(milliseconds: 180);

  @override
  Widget build(BuildContext context) {
    final success = feedback?['correct'] == true;
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        backgroundColor: _forest,
        appBar: AppBar(
          toolbarHeight: MediaQuery.textScalerOf(context).scale(13) > 18
              ? 80
              : 56,
          backgroundColor: _forest,
          foregroundColor: _paper,
          leading: IconButton(
            onPressed: busy ? null : onPause,
            tooltip: practice ? 'Quitter le jeu' : 'Mettre la balade en pause',
            icon: const Icon(Icons.close),
          ),
          title: Tooltip(
            message:
                '${practice ? 'Jeu libre' : journeyName ?? 'Ma balade'} · $step/$total',
            child: Text(
              '${practice ? 'Jeu libre' : journeyName ?? 'Ma balade'} · $step/$total',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
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
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 20),
                child: Text(
                  practice ? 'LIBRE' : '$score plumes',
                  style: TextStyle(color: _paper, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
        body: GameEffects(
          event: feedback == null
              ? null
              : '${question.id}:${feedback['choice']}',
          success: success,
          child: GardenBackdrop(
            illustrated: true,
            child: SafeArea(
              bottom: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                    children: [
                      LinearProgressIndicator(
                        value: step / total,
                        minHeight: 4,
                        color: const Color(0xff78b5ab),
                        backgroundColor: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 16),
                      FieldPaper(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                if (!photo) ...[
                                  Pio(level: companionLevel, size: 46),
                                  const SizedBox(width: 12),
                                ],
                                Expanded(
                                  child: Text(
                                    photo
                                        ? 'Quel oiseau observes-tu ?'
                                        : 'À qui appartient cet indice ?',
                                    style: const TextStyle(
                                      color: _ink,
                                      fontSize: 24,
                                      height: 1.15,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (photo) ...[
                              Container(
                                padding: const EdgeInsets.all(4),
                                clipBehavior: Clip.antiAlias,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(18),
                                  child: BirdPhoto(
                                    species: question.species,
                                    media: question.data['photo'] == null
                                        ? null
                                        : Map<String, dynamic>.from(
                                            question.data['photo'],
                                          ),
                                    height: feedback == null ? 240 : 180,
                                    semanticLabel: 'Oiseau à identifier',
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              if (feedback == null)
                                TextButton.icon(
                                  onPressed: onSource,
                                  icon: const Icon(
                                    Icons.info_outline,
                                    size: 14,
                                  ),
                                  style: TextButton.styleFrom(
                                    foregroundColor: photo ? _ink : _paper,
                                    backgroundColor: photo
                                        ? const Color(0xffe5f0f4)
                                        : const Color(0xee102d29),
                                    minimumSize: const Size(48, 48),
                                  ),
                                  label: const Text(
                                    'Source & crédit photo',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                            ],
                            if (!photo || feedback != null)
                              DragTarget<int>(
                                onWillAcceptWithDetails: (d) =>
                                    !locked &&
                                    d.data >= 0 &&
                                    d.data < question.options.length,
                                onAcceptWithDetails: (d) => onSelect(d.data),
                                builder: (context, candidates, rejected) =>
                                    AnimatedContainer(
                                      duration: duration(context),
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: photo
                                              ? [
                                                  success ? _mint : _peach,
                                                  success ? _mint : _peach,
                                                ]
                                              : [gameButter, gameButter],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        border: Border.all(
                                          color: candidates.isNotEmpty
                                              ? Colors.white
                                              : photo
                                              ? Colors.white
                                              : _gold,
                                          width: candidates.isNotEmpty
                                              ? 3
                                              : 1.5,
                                        ),
                                        borderRadius: BorderRadius.circular(18),
                                        boxShadow: [
                                          BoxShadow(
                                            color: candidates.isNotEmpty
                                                ? const Color(0x88e8c778)
                                                : photo
                                                ? Colors.transparent
                                                : const Color(0x33000000),
                                            blurRadius: 20,
                                            offset: const Offset(0, 5),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                feedback == null
                                                    ? Icons.auto_awesome
                                                    : success
                                                    ? Icons.verified
                                                    : Icons.explore_outlined,
                                                size: 20,
                                                color: _forest,
                                              ),
                                              const SizedBox(width: 8),
                                              Flexible(
                                                child: Text(
                                                  feedback == null
                                                      ? 'L’INDICE DU NATURALISTE'
                                                      : success
                                                      ? practice
                                                            ? 'Bien observé !'
                                                            : 'Bien observé ! +${feedback['points']} plumes'
                                                      : 'À retenir',
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(
                                                    color: _forest,
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            feedback == null
                                                ? question.clues.first
                                                : photo
                                                ? '${question.options[question.answer]}\n${question.explanation}'
                                                : question.explanation,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              color: _forest,
                                              fontSize: 17,
                                              height: 1.35,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          if (feedback != null)
                                            TextButton(
                                              onPressed: onSource,
                                              style: TextButton.styleFrom(
                                                foregroundColor: _forest,
                                              ),
                                              child: const Text(
                                                'Voir la source & le crédit photo ↗',
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                              ),
                            const SizedBox(height: 12),
                            if (!photo ||
                                busy ||
                                feedback != null ||
                                selected != null)
                              Semantics(
                                liveRegion: true,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 9,
                                  ),
                                  decoration: BoxDecoration(
                                    color: gameButter,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    feedback != null
                                        ? success
                                              ? 'Bien joué, tu l’as reconnu !'
                                              : 'La bonne réponse est indiquée ci-dessous.'
                                        : selected == null
                                        ? photo
                                              ? 'Enregistrement de ta réponse…'
                                              : 'Touche une carte, ou maintiens-la pour la glisser.'
                                        : 'Carte choisie : ${question.options[selected!]}.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: _ink,
                                      fontSize: 13,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ),
                            if (feedback == null || feedback['correct'] != true)
                              NaturalistGuideButton(
                                beforeHint: beforeHint,
                                question: question,
                                pastel: photo,
                                answered: feedback != null,
                                enabled: !busy,
                              ),
                            const SizedBox(height: 12),
                            if (photo) ...[
                              for (final i in JourneyOptionOrder.indices(context, question.options.length))
                                if (feedback == null ||
                                    i == feedback['answer'] ||
                                    i == feedback['choice'])
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: RetryChoice(
                                      index: i,
                                      child: photoOption(context, i),
                                    ),
                                  ),
                            ] else
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final columns =
                                      constraints.maxWidth < 290 ||
                                          MediaQuery.textScalerOf(
                                                context,
                                              ).scale(16) >
                                              24
                                      ? 1
                                      : 2;
                                  final width =
                                      (constraints.maxWidth -
                                          (columns - 1) * 12) /
                                      columns;
                                  return Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: [
                                      for (final i in JourneyOptionOrder.indices(context, question.options.length))
                                        SizedBox(
                                          width: width,
                                          child: RetryChoice(
                                            index: i,
                                            child: card(context, i, width),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                            if (error != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: Semantics(
                                  liveRegion: true,
                                  child: Text(
                                    error!,
                                    style: TextStyle(
                                      color: photo ? _ink : _paper,
                                    ),
                                  ),
                                ),
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
        ),
        bottomNavigationBar: photo && feedback == null
            ? null
            : Container(
                decoration: BoxDecoration(
                  color: photo ? _sky : _forest,
                  border: Border(
                    top: BorderSide(
                      color: photo ? Colors.white : const Color(0xff496354),
                    ),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Center(
                    heightFactor: 1,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            elevation: photo ? 0 : 7,
                            shadowColor: const Color(0xff000000),
                            side: const BorderSide(
                              color: Color(0xffffe8af),
                              width: 1.5,
                            ),
                            backgroundColor: photo ? _butter : _gold,
                            foregroundColor: _forest,
                            disabledBackgroundColor: photo
                                ? const Color(0xffdfe6e8)
                                : const Color(0xff385047),
                            disabledForegroundColor: photo
                                ? _ink
                                : const Color(0xffb4c3b8),
                            minimumSize: const Size(double.infinity, 54),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: busy
                              ? null
                              : feedback != null
                              ? onNext
                              : selected == null
                              ? null
                              : onConfirm,
                          child: Text(
                            busy
                                ? 'Sauvegarde…'
                                : feedback != null
                                ? practice
                                      ? step == total
                                            ? 'Terminer le jeu'
                                            : 'Oiseau suivant →'
                                      : step == total
                                      ? 'Découvrir mon bilan'
                                      : 'Continuer →'
                                : selected == null
                                ? 'Choisis un oiseau'
                                : 'Valider mon choix',
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget photoOption(BuildContext context, int index) {
    final correct = feedback != null && feedback['answer'] == index;
    final wrong = feedback != null && feedback['choice'] == index && !correct;
    return QuestButton(
      // A revealed answer stays fully legible while further choices are locked.
      dimWhenDisabled: feedback == null,
      pastelColor: correct
          ? _mint
          : wrong
          ? _peach
          : gameButter,
      gold: correct,
      wrong: wrong,
      onPressed: locked ? null : () => onSelect(index),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .8),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x10000000),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: correct || wrong
                ? Icon(
                    correct ? Icons.check : Icons.close,
                    color: _ink,
                    size: 19,
                  )
                : Text(
                    String.fromCharCode(65 + JourneyOptionOrder.indices(context, question.options.length).indexOf(index)),
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              question.options[index],
              style: TextStyle(
                color: _ink,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
          if (correct) const Icon(Icons.verified, color: _forest, size: 21),
        ],
      ),
    );
  }

  Widget card(BuildContext context, int index, double width) {
    final option = question.options[index];
    final bird = species.firstWhere((b) => b['name'] == option);
    final correct = feedback != null && feedback['answer'] == index;
    final wrong = feedback != null && feedback['choice'] == index && !correct;
    final chosen = feedback == null && selected == index;
    final highlighted = chosen || correct;
    final border = wrong
        ? const Color(0xffefa88b)
        : highlighted
        ? _gold
        : const Color(0xff607566);
    final label = correct
        ? 'Bonne réponse'
        : wrong
        ? 'Ton choix'
        : chosen
        ? 'Carte choisie'
        : null;
    final face = AnimatedContainer(
      duration: duration(context),
      decoration: BoxDecoration(
        color: highlighted ? _mint : gameButter,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 2),
        boxShadow: [
          BoxShadow(
            color: highlighted
                ? const Color(0x44e8c778)
                : const Color(0x44000000),
            blurRadius: highlighted ? 16 : 6,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                BirdPhoto(species: bird['id'], height: 94),
                if (label != null)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: wrong ? const Color(0xffa34029) : _forest,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        wrong
                            ? Icons.close
                            : correct
                            ? Icons.check
                            : Icons.link,
                        color: _paper,
                        size: 18,
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 3),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.textScalerOf(context).scale(35),
                ),
                child: Center(
                  child: Text(
                    option,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      height: 1.15,
                      color: _forest,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
              child: Text(
                label ??
                    (feedback == null
                        ? 'Toucher pour choisir'
                        : 'Autre oiseau'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: wrong
                      ? const Color(0xff923620)
                      : const Color(0xff52634c),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return Semantics(
      button: true,
      selected: highlighted,
      enabled: !locked,
      label: '$option${label == null ? '' : ', $label'}',
      excludeSemantics: true,
      onTap: locked ? null : () => onSelect(index),
      child: LongPressDraggable<int>(
        data: index,
        maxSimultaneousDrags: locked ? 0 : 1,
        feedback: Material(
          color: Colors.transparent,
          child: SizedBox(
            width: width,
            child: Transform.rotate(angle: -.05, child: face),
          ),
        ),
        childWhenDragging: Opacity(opacity: .35, child: face),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: locked ? null : () => onSelect(index),
            borderRadius: BorderRadius.circular(16),
            child: face,
          ),
        ),
      ),
    );
  }
}
