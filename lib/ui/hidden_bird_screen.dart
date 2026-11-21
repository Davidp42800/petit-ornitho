import 'letter_keyboard.dart';
import 'pepi_hint_button.dart';
import 'game_effects.dart';
import 'package:flutter/material.dart';
import '../data/game_store.dart';
import '../domain/hidden_bird.dart';
import '../domain/practice_replay.dart';
import 'components.dart';
import 'garden_backdrop.dart';
import 'pio.dart';
import 'quest_materials.dart';
import 'bird_photo.dart';
import 'naturalist_guide.dart';
import 'letter_delivery.dart';

/// Letter exploration is practice: never replaces or rewards a saved journey.
class HiddenBirdScreen extends StatefulWidget {
  final GameStore store;
  const HiddenBirdScreen({super.key, required this.store});
  @override
  State<HiddenBirdScreen> createState() => _HiddenBirdScreenState();
}

class _HiddenBirdScreenState extends State<HiddenBirdScreen> {
  late final birds = List<dynamic>.of(
    widget.store.playableSpecies.where(
      (b) => b['clues'] is List && (b['clues'] as List).isNotEmpty,
    ),
  )..shuffle();
  late HiddenBird puzzle = HiddenBird(birds.first['name']);
  final scroll = ScrollController();
  final letterKeys = <String, GlobalKey>{};
  OverlayEntry? delivery;
  bool delivering = false;
  String? highlightedLetter;
  void depositLetter() {
    if (!mounted) return;
    setState(() {
      final char = puzzle.reveal();
      highlightedLetter = char == null ? null : baseLetter(char);
      message = puzzle.complete
          ? 'Bravo ! Voici ${bird['name']} !'
          : 'Les amis de Pépi ont apporté la lettre $char !';
    });
  }

  Future<void> revealWithBirds() async {
    if (delivering || puzzle.complete) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      depositLetter();
      return;
    }
    final words = (bird['name'] as String).toUpperCase().split(' ');
    GlobalKey? targetKey;
    String? letter;
    for (final (wi, word) in words.indexed) {
      for (var i = 0; i < word.length; i++) {
        if (!puzzle.visible(word[i])) {
          targetKey = letterKeys['$wi:$i'];
          letter = word[i];
          break;
        }
      }
      if (letter != null) break;
    }
    if (targetKey?.currentContext == null || letter == null) {
      depositLetter();
      return;
    }
    setState(() => delivering = true);
    await Scrollable.ensureVisible(
      targetKey!.currentContext!,
      alignment: .38,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
    if (!mounted) return;
    final overlay = Overlay.of(context);
    Offset target() {
      final box = targetKey!.currentContext?.findRenderObject();
      final overlayBox = overlay.context.findRenderObject();
      if (box is RenderBox && overlayBox is RenderBox) {
        return overlayBox.globalToLocal(
          box.localToGlobal(box.size.center(Offset.zero)),
        );
      }
      return MediaQuery.sizeOf(context).center(Offset.zero);
    }

    delivery = OverlayEntry(
      builder: (_) => Positioned.fill(
        child: LetterDelivery(
          letter: letter!,
          target: target,
          onDeposit: depositLetter,
          onDone: () {
            delivery?.remove();
            delivery = null;
            if (mounted) setState(() => delivering = false);
          },
        ),
      ),
    );
    overlay.insert(delivery!);
  }

  @override
  void dispose() {
    delivery?.remove();
    delivery = null;
    scroll.dispose();
    super.dispose();
  }

  int round = 0, clues = 1;
  bool finished = false;
  String message = 'Touche une lettre pour voir si elle se cache dans le nom.';
  dynamic get bird => birds[round];
  void guess(String char) => setState(() {
    final found = puzzle.guess(char);
    message = puzzle.complete
        ? 'Bravo ! Tu as découvert ${bird['name']} !'
        : found
        ? 'Bien vu ! La lettre $char est dans le nom.'
        : 'Pas de $char ici. Essaie une autre lettre !';
  });
  void next() {
    scroll.jumpTo(0);
    setState(() {
      if (round + 1 == birds.length) {
        finished = true;
        return;
      }
      round++;
      puzzle = HiddenBird(bird['name']);
      highlightedLetter = null;
      clues = 1;
      message = 'Un nouvel oiseau se cache. À toi de jouer !';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (birds.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Oiseau caché')),
        body: const Center(child: Text('Les oiseaux arrivent bientôt.')),
      );
    }
    final q = widget.store.questions
        .where((q) => q.species == bird['id'] && q.kind == 'mystery')
        .firstOrNull;
    return LetterKeyboard(
      enabled: !delivering && !puzzle.complete && !finished,
      onLetter: (letter) {
        if (!puzzle.isLetter(letter) ||
            puzzle.guessed.contains(baseLetter(letter))) {
          return false;
        }
        guess(letter);
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Oiseau caché'),
          leading: IconButton(
            tooltip: 'Quitter le jeu',
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: GameEffects(
          event: puzzle.complete ? '$round:found' : null,
          success: true,
          child: GardenBackdrop(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: ListView(
                  controller: scroll,
                  physics: delivering
                      ? const NeverScrollableScrollPhysics()
                      : null,
                  padding: const EdgeInsets.all(16),
                  children: [
                    PioGreeting(
                      level: widget.store.unlocked,
                      title: finished ? 'Tous découverts !' : 'Qui suis-je ?',
                      message: finished
                          ? 'Tu as retrouvé les ${birds.length} oiseaux cachés !'
                          : 'Lis l’indice et découvre les lettres de mon nom.',
                    ),
                    const SizedBox(height: 16),
                    if (finished)
                      FieldPaper(
                        child: Column(
                          children: [
                            const Icon(
                              Icons.auto_awesome,
                              size: 64,
                              color: green,
                            ),
                            Text(
                              '${birds.length} oiseaux découverts',
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: () => setState(() {
                                if (scroll.hasClients) scroll.jumpTo(0);
                                final previousFirst = birds.first['id'] as String;
                                final previousLast = bird['id'] as String;
                                round = 0;
                                clues = 1;
                                finished = false;
                                birds.shuffle();
                                varyReplayOpening(birds, (b) => b['id'] as String, previousFirst, previousLast);
                                puzzle = HiddenBird(bird['name']);
                                highlightedLetter = null;
                                message = 'C’est reparti !';
                              }),
                              child: const Text('Rejouer'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Retour aux jeux'),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      FieldPaper(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'OISEAU ${round + 1} / ${birds.length}',
                              style: const TextStyle(
                                color: green,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 12),
                            for (final clue in (bird['clues'] as List).take(
                              clues,
                            ))
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Text(
                                  clue,
                                  style: const TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w700,
                                    color: ink,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 12),
                            // One row per word; Wrap also handles long words on small screens.
                            for (final (wi, word)
                                in (bird['name'] as String)
                                    .toUpperCase()
                                    .split(' ')
                                    .indexed)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: 4,
                                  runSpacing: 6,
                                  children: [
                                    for (var i = 0; i < word.length; i++)
                                      Semantics(
                                        label: puzzle.visible(word[i])
                                            ? 'Lettre ${word[i]}'
                                            : 'Lettre cachée',
                                        excludeSemantics: true,
                                        child: AnimatedContainer(
                                          key: letterKeys.putIfAbsent(
                                            '$wi:$i',
                                            GlobalKey.new,
                                          ),
                                          duration: const Duration(
                                            milliseconds: 240,
                                          ),
                                          constraints: const BoxConstraints(
                                            minWidth: 25,
                                            minHeight: 40,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            boxShadow:
                                                highlightedLetter ==
                                                    baseLetter(word[i])
                                                ? const [
                                                    BoxShadow(
                                                      color: Color(0x88ffd56b),
                                                      blurRadius: 16,
                                                      spreadRadius: 2,
                                                    ),
                                                  ]
                                                : const [],
                                            color: puzzle.visible(word[i])
                                                ? const Color(0xffffdc77)
                                                : const Color(0xffdceef4),
                                            borderRadius: BorderRadius.circular(
                                              7,
                                            ),
                                            border: Border.all(
                                              color: green.withValues(
                                                alpha: .35,
                                              ),
                                            ),
                                          ),
                                          child: Text(
                                            puzzle.visible(word[i])
                                                ? word[i]
                                                : '—',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w900,
                                              color: ink,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                message,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: ink,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (!puzzle.complete) ...[
                        const SizedBox(height: 20),
                        PepiHintButton(
                          label: 'Découvrir une lettre',
                          onPressed: delivering ? null : revealWithBirds,
                        ),
                        if (q != null)
                          NaturalistGuideButton(
                            question: q,
                            answered: false,
                            enabled: !delivering,
                            pastel: true,
                          ),
                        if (clues < (bird['clues'] as List).length)
                          TextButton.icon(
                            onPressed: delivering
                                ? null
                                : () => setState(() => clues++),
                            icon: const Icon(Icons.search),
                            label: const Text('Un indice de plus'),
                          ),

                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 6,
                          runSpacing: 8,
                          children: [
                            for (final char
                                in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split(''))
                              SizedBox(
                                width: 48,
                                height: 52,
                                child: FilledButton(
                                  style: FilledButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    backgroundColor: gameButter,
                                    foregroundColor: ink,
                                    disabledBackgroundColor: const Color(
                                      0xffd0dfe5,
                                    ),
                                    disabledForegroundColor: const Color(
                                      0xff526978,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed:
                                      delivering ||
                                          puzzle.guessed.contains(char)
                                      ? null
                                      : () => guess(char),
                                  child: Text(
                                    char,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ] else ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: BirdPhoto(
                            species: bird['id'],
                            semanticLabel: bird['name'],
                          ),
                        ),
                        const SizedBox(height: 12),
                        QuestButton(
                          gold: true,
                          onPressed: delivering ? null : next,
                          child: Text(
                            round + 1 == birds.length
                                ? 'Terminer le jeu'
                                : 'Oiseau suivant →',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: ink,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        if (q != null)
                          NaturalistGuideButton(question: q, answered: true),
                        TextButton(
                          onPressed: () => sourceDialog(
                            context,
                            bird['source'],
                            bird['publisher'],
                            widget.store.media
                                .where((m) => m['id'] == bird['id'])
                                .firstOrNull,
                          ),
                          child: const Text('Sources & crédit photo'),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
