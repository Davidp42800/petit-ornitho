import 'dart:math';
import 'package:flutter/material.dart';
import 'letter_keyboard.dart';
import '../domain/game.dart';
import '../domain/hidden_bird.dart';
import 'components.dart';
import 'letter_delivery.dart';
import 'pepi_hint_button.dart';

/// A name-recall mission. Assistance is persisted before any letter is exposed.
/// The existing server still grades the selected name, never a local success.
class HiddenNameInput extends StatefulWidget {
  final Question question;
  final bool locked;
  final Future<bool> Function()? beforeHint, beforeSpellingHelp;
  final ValueChanged<int> onAnswer;
  final Widget? photoHint;
  const HiddenNameInput({
    super.key,
    required this.question,
    required this.locked,
    required this.beforeHint,
    this.beforeSpellingHelp,
    required this.onAnswer,
    this.photoHint,
  });

  @override
  State<HiddenNameInput> createState() => _HiddenNameInputState();
}

class _HiddenNameInputState extends State<HiddenNameInput> {
  late final puzzle = HiddenBird(
    widget.question.options[widget.question.answer],
  );
  final input = TextEditingController();
  final destination = GlobalKey();
  OverlayEntry? delivery;
  bool helping = false, submitted = false;
  @override
  void didUpdateWidget(covariant HiddenNameInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.locked && !widget.locked) submitted = false;
  }

  bool get complete => characters.asMap().entries.every(
    (e) => !puzzle.isLetter(e.value) || correctSlot(e.key),
  );
  void submitIfComplete() {
    if (complete) submit();
  }

  String? message;

  late final characters = puzzle.name.toUpperCase().split('');
  late final bank = characters.where(puzzle.isLetter).toList()
    ..shuffle(Random());
  final placements = <int, int>{};
  final fixedSlots = <int>{};
  final rejectedLetters = <int, String>{};
  int rejectionTick = 0;
  late int? selectedSlot = characters.indexWhere(puzzle.isLetter);

  void shuffleLetters() {
    if (widget.locked || helping || submitted) return;
    final available = [
      for (var i = 0; i < bank.length; i++)
        if (!placements.containsValue(i)) i,
    ];
    final letters = available.map((i) => bank[i]).toList();
    if (letters.toSet().length < 2) return;
    letters.shuffle();
    // A tap should visibly change the order, even with repeated letters.
    if (List.generate(
      available.length,
      (i) => bank[available[i]] == letters[i],
    ).every((same) => same)) {
      letters.add(letters.removeAt(0));
    }
    setState(() {
      for (var i = 0; i < available.length; i++) {
        bank[available[i]] = letters[i];
      }
    });
  }

  int? nextEmptySlot(int after) {
    for (var step = 1; step <= characters.length; step++) {
      final i = (after + step) % characters.length;
      if (puzzle.isLetter(characters[i]) && !correctSlot(i)) return i;
    }
    return null;
  }

  bool correctSlot(int slot) =>
      placements.containsKey(slot) &&
      baseLetter(bank[placements[slot]!]) == baseLetter(characters[slot]);

  Widget letterEffect(int slot, Widget child) {
    if (rejectedLetters.containsKey(slot)) {
      return TweenAnimationBuilder<double>(
        key: ValueKey('wrong-$slot-$rejectionTick'),
        tween: Tween(begin: 0, end: 1),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 360),
        builder: (context, progress, child) => Transform.translate(
          offset: Offset(sin(progress * pi * 6) * 6 * (1 - progress), 0),
          child: child,
        ),
        child: child,
      );
    }
    return TweenAnimationBuilder<double>(
      key: ValueKey('placed-$slot-${placements[slot]}'),
      tween: Tween(begin: correctSlot(slot) ? .65 : 1.0, end: 1.0),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 350),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: child,
    );
  }

  void syncInput() {
    input.text = List.generate(
      characters.length,
      (i) => puzzle.isLetter(characters[i])
          ? (placements.containsKey(i) ? characters[i] : '_')
          : characters[i],
    ).join();
  }

  void placeLetter(int token) {
    if (widget.locked ||
        helping ||
        selectedSlot == null ||
        placements.containsValue(token)) {
      return;
    }
    setState(() {
      final slot = selectedSlot!;
      if (baseLetter(bank[token]) != baseLetter(characters[slot])) {
        rejectionTick++;
        rejectedLetters[slot] = bank[token];
        message = 'Pas cette lettre ! Essaie une autre touche.';
        return;
      }
      rejectedLetters.remove(slot);
      placements[slot] = token;
      syncInput();
      if (correctSlot(slot)) {
        selectedSlot = nextEmptySlot(slot);
        message = selectedSlot == null
            ? 'Bravo, tu as trouvé !'
            : '✓ Bien placé ! Continue avec la prochaine lettre.';
      } else {
        message = 'Cette lettre ne va pas ici. Choisis-en une autre.';
      }
    });
    submitIfComplete();
  }

  bool handleKeyboard(String letter) {
    if (widget.locked ||
        helping ||
        submitted ||
        !puzzle.isLetter(letter) ||
        selectedSlot == null) {
      return false;
    }
    final token = bank
        .asMap()
        .entries
        .where(
          (e) =>
              !placements.containsValue(e.key) &&
              baseLetter(e.value) == baseLetter(letter),
        )
        .firstOrNull;
    if (token != null) {
      placeLetter(token.key);
    } else {
      setState(() {
        rejectedLetters[selectedSlot!] = letter;
        rejectionTick++;
        message = 'Pas cette lettre ! Essaie une autre touche.';
      });
    }
    return true;
  }

  void fillRevealed(String letter) {
    final normalized = baseLetter(letter);
    final slots = [
      for (var i = 0; i < characters.length; i++)
        if (baseLetter(characters[i]) == normalized) i,
    ];
    placements.removeWhere(
      (slot, token) =>
          slots.contains(slot) || baseLetter(bank[token]) == normalized,
    );
    final tokens = [
      for (var i = 0; i < bank.length; i++)
        if (baseLetter(bank[i]) == normalized) i,
    ];
    for (var i = 0; i < slots.length; i++) {
      rejectedLetters.remove(slots[i]);
      placements[slots[i]] = tokens[i];
      fixedSlots.add(slots[i]);
    }
    selectedSlot = nextEmptySlot(-1);
    syncInput();
  }

  Widget letterSlots(bool locked) {
    var offset = 0;
    final rows = <Widget>[];
    for (final word in puzzle.name.toUpperCase().split(' ')) {
      final start = offset;
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 5,
            runSpacing: 5,
            children: [
              for (var j = 0; j < word.length; j++)
                if (!puzzle.isLetter(word[j]))
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(word[j]),
                  )
                else
                  SizedBox(
                    width: 44,
                    height: 48,
                    child: OutlinedButton(
                      key: ValueKey('letter-slot-${start + j}'),
                      onPressed: locked || fixedSlots.contains(start + j)
                          ? null
                          : () => setState(() {
                              if (rejectedLetters.isNotEmpty) {
                                rejectedLetters.clear();
                                message = null;
                              }
                              selectedSlot = start + j;
                            }),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor: rejectedLetters.containsKey(start + j)
                            ? const Color(0xffffd9d5)
                            : fixedSlots.contains(start + j)
                            ? const Color(0xffffe6a7)
                            : selectedSlot == start + j
                            ? const Color(0xffb4e6dc)
                            : correctSlot(start + j)
                            ? const Color(0xffcfebd4)
                            : const Color(0xffdceef4),
                        foregroundColor: rejectedLetters.containsKey(start + j)
                            ? const Color(0xffa52b32)
                            : ink,
                        disabledForegroundColor: ink,
                        side: BorderSide(
                          color: rejectedLetters.containsKey(start + j)
                              ? const Color(0xffc13f49)
                              : selectedSlot == start + j
                              ? const Color(0xff007f83)
                              : const Color(0xffb6d4e3),
                          width: selectedSlot == start + j ? 3 : 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Semantics(
                        label:
                            'Case ${start + j + 1}${fixedSlots.contains(start + j) ? ', indice' : ''}',
                        child: letterEffect(
                          start + j,
                          Text(
                            rejectedLetters.containsKey(start + j)
                                ? rejectedLetters[start + j]!
                                : placements.containsKey(start + j)
                                ? characters[start + j]
                                : '—',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
            ],
          ),
        ),
      );
      offset += word.length + 1;
    }
    return Column(key: destination, children: rows);
  }

  Future<void> submit() async {
    if (widget.locked || helping || submitted) return;
    if (characters.asMap().entries.any(
      (entry) => puzzle.isLetter(entry.value) && !correctSlot(entry.key),
    )) {
      setState(
        () => message =
            'Complète les cases avec les bonnes lettres avant de valider.',
      );
      return;
    }
    submitted = true;
    widget.onAnswer(widget.question.answer);
  }

  Future<void> help() async {
    if (widget.locked || helping || puzzle.complete) return;
    setState(() => helping = true);
    var allowed = false;
    try {
      allowed = await widget.beforeHint?.call() ?? false;
    } catch (_) {
      // A failed save must never expose assistance without recording it.
    }
    if (!mounted) return;
    if (!allowed) {
      setState(() {
        helping = false;
        message = 'L’aide n’a pas pu être enregistrée. Réessaie.';
      });
      return;
    }
    final letter = puzzle.pickHiddenLetter()!;
    void deposit() {
      if (!mounted) return;
      setState(() {
        puzzle.reveal(letter);
        fillRevealed(letter);
        message = 'Pépi t’a apporté la lettre ${letter.toUpperCase()} !';
      });
    }

    if (MediaQuery.disableAnimationsOf(context)) {
      deposit();
      setState(() => helping = false);
      submitIfComplete();
      return;
    }
    final overlay = Overlay.of(context);
    delivery = OverlayEntry(
      builder: (_) => Positioned.fill(
        child: LetterDelivery(
          letter: letter.toUpperCase(),
          target: () {
            final box = destination.currentContext?.findRenderObject();
            final root = overlay.context.findRenderObject();
            if (box is RenderBox && root is RenderBox) {
              return root.globalToLocal(
                box.localToGlobal(box.size.center(Offset.zero)),
              );
            }
            return Offset.zero;
          },
          onDeposit: deposit,
          onDone: () {
            delivery?.remove();
            delivery = null;
            if (mounted) {
              setState(() => helping = false);
              submitIfComplete();
            }
          },
        ),
      ),
    );
    overlay.insert(delivery!);
  }

  @override
  void dispose() {
    delivery?.remove();
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locked = widget.locked || helping;
    return LetterKeyboard(
      enabled: !locked && !submitted,
      onLetter: handleKeyboard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Complète mon nom',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: ink,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Tape au clavier ou choisis les lettres en dessous : la case suivante se sélectionne toute seule.',
          ),
          const SizedBox(height: 12),
          letterSlots(locked),
          const SizedBox(height: 8),
          const Text(
            'Indices : 15 plumes sans aide · 10 plumes avec 1 · 5 plumes avec 2 ou plus',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: muted),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: PepiHintButton(
                  label: 'Découvrir une lettre',
                  onPressed: locked || puzzle.complete ? null : () => help(),
                ),
              ),
              if (widget.photoHint != null) Expanded(child: widget.photoHint!),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xfffff2d4),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        selectedSlot == null
                            ? 'Nom complété !'
                            : 'À toi : lettre ${selectedSlot! + 1}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton.filled(
                      tooltip: 'Mélanger les lettres',
                      key: const ValueKey('shuffle-letters'),
                      onPressed:
                          locked ||
                              submitted ||
                              {
                                    for (var i = 0; i < bank.length; i++)
                                      if (!placements.containsValue(i)) bank[i],
                                  }.length <
                                  2
                          ? null
                          : shuffleLetters,
                      icon: const Icon(Icons.autorenew_rounded, size: 24),
                      style: IconButton.styleFrom(
                        fixedSize: const Size(48, 48),
                        padding: EdgeInsets.zero,
                        backgroundColor: const Color(0xffd3eaf4),
                        foregroundColor: ink,
                        shape: const CircleBorder(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    for (var i = 0; i < bank.length; i++)
                      SizedBox(
                        width: 44,
                        height: 48,
                        child: OutlinedButton(
                          key: ValueKey('bank-letter-$i'),
                          onPressed:
                              locked ||
                                  placements.containsValue(i) ||
                                  selectedSlot == null
                              ? null
                              : () => placeLetter(i),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            backgroundColor: placements.containsValue(i)
                                ? const Color(0xffeee6d4)
                                : Colors.white,
                            foregroundColor: ink,
                          ),
                          child: Text(
                            placements.containsValue(i) ? '·' : bank[i],
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                if (selectedSlot != null &&
                    placements.containsKey(selectedSlot))
                  TextButton(
                    onPressed: locked
                        ? null
                        : () => setState(() {
                            placements.remove(selectedSlot);
                            syncInput();
                          }),
                    child: const Text('Retirer cette lettre'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (complete && !locked && !submitted)
            TextButton(
              onPressed: submit,
              child: const Text('Réessayer l’enregistrement'),
            ),
          const SizedBox(height: 8),
          if (message != null)
            Semantics(
              liveRegion: true,
              child: Text(
                message!,
                style: const TextStyle(color: ink),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}
