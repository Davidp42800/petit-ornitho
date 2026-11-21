import 'retry_feedback.dart';
import 'quest_materials.dart';
import 'package:flutter/material.dart';
import '../domain/game.dart';
import 'bird_photo.dart';

/// Permutation index is only a transport encoding; children manipulate birds.
class RankingChoice extends StatefulWidget {
  final Question question;
  final bool locked;
  final ValueChanged<int> onAnswer;
  const RankingChoice({
    super.key,
    required this.question,
    required this.locked,
    required this.onAnswer,
  });
  @override
  State<RankingChoice> createState() => _RankingChoiceState();
}

class _RankingChoiceState extends State<RankingChoice> {
  late List<int> order = List<int>.from(widget.question.data['initial_order']);
  final correctionKey = GlobalKey();
  Set<int> lastWrong = {};
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final wrong =
        context.dependOnInheritedWidgetOfExactType<RetryFeedback>()?.wrong ??
        <int>{};
    if (wrong.length > lastWrong.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && correctionKey.currentContext != null) {
          Scrollable.ensureVisible(
            correctionKey.currentContext!,
            alignment: .1,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 250),
          );
        }
      });
    }
    lastWrong = Set.of(wrong);
  }

  void move(int from, int to) {
    if (widget.locked || to < 0 || to >= order.length) return;
    setState(() => order.insert(to, order.removeAt(from)));
  }

  @override
  Widget build(BuildContext context) {
    final birds = widget.question.data['ranking_birds'] as List;
    final retry = context.dependOnInheritedWidgetOfExactType<RetryFeedback>();
    final reviewed =
        retry?.wrong.isNotEmpty == true && retry?.correctAnswer != null;
    final expected = reviewed
        ? List<int>.from(
            widget.question.data['permutations'][retry!.correctAnswer!],
          )
        : <int>[];
    final misplaced = reviewed
        ? order.asMap().entries.where((e) => expected[e.key] != e.value).length
        : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (reviewed)
          Container(
            key: correctionKey,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: misplaced == 0
                  ? const Color(0xffcfebd4)
                  : const Color(0xffffd9d5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Semantics(
              liveRegion: true,
              child: Text(
                misplaced == 0
                    ? 'Tout est bien placé ! Valide ton classement.'
                    : '$misplaced oiseaux à déplacer. Les cartes rouges indiquent la bonne place.',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        const Text(
          'Glisse les cartes ou utilise les flèches. Vérifie ton ordre avant de le valider.',
        ),
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          onReorder: (from, to) => move(from, to > from ? to - 1 : to),
          children: [
            for (var position = 0; position < order.length; position++)
              Card(
                key: ValueKey('rank-${order[position]}'),
                color: !reviewed
                    ? gameButter
                    : expected[position] == order[position]
                    ? const Color(0xffcfebd4)
                    : const Color(0xffffd9d5),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text(
                            '${position + 1}',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${birds[order[position]]['name']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            key: ValueKey('rank-up-${order[position]}'),
                            tooltip: 'Monter ${birds[order[position]]['name']}',
                            onPressed: widget.locked || position == 0
                                ? null
                                : () => move(position, position - 1),
                            icon: const Icon(Icons.arrow_upward),
                          ),
                          IconButton(
                            tooltip:
                                'Descendre ${birds[order[position]]['name']}',
                            onPressed:
                                widget.locked || position == order.length - 1
                                ? null
                                : () => move(position, position + 1),
                            icon: const Icon(Icons.arrow_downward),
                          ),
                          ReorderableDragStartListener(
                            index: position,
                            enabled: !widget.locked,
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(Icons.drag_handle),
                            ),
                          ),
                        ],
                      ),
                      if (reviewed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Icon(
                                expected[position] == order[position]
                                    ? Icons.check_circle_outline
                                    : Icons.swap_vert,
                                color: expected[position] == order[position]
                                    ? const Color(0xff087a83)
                                    : const Color(0xffa52b32),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  expected[position] == order[position]
                                      ? 'Bien placé · rang ${position + 1}'
                                      : 'À déplacer au rang ${expected.indexOf(order[position]) + 1}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      BirdPhoto(
                        species: '${birds[order[position]]['id']}',
                        media: Map<String, dynamic>.from(
                          birds[order[position]]['photo'],
                        ),
                        height: 110,
                      ),
                      Text(
                        '${birds[order[position]]['photo']['author']} · ${birds[order[position]]['photo']['license']}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        FilledButton(
          key: const ValueKey('rank-confirm'),
          onPressed: widget.locked
              ? null
              : () {
                  final permutations =
                      widget.question.data['permutations'] as List;
                  final answer = permutations.indexWhere(
                    (p) => p.join(',') == order.join(','),
                  );
                  if (answer >= 0) widget.onAnswer(answer);
                },
          child: const Text('Valider mon classement'),
        ),
      ],
    );
  }
}
