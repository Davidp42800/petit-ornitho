import 'journey_option_order.dart';
import 'retry_feedback.dart';
import 'quest_materials.dart';
import 'package:flutter/material.dart';
import '../domain/game.dart';
import 'bird_photo.dart';
import 'components.dart';
import 'pio.dart';
import 'naturalist_guide.dart';

class PictureChoiceBoard extends StatelessWidget {
  final Question question;
  final Map<String, dynamic>? feedback;
  final bool busy;
  final int step, total;
  final ValueChanged<int> onAnswer;
  final VoidCallback onNext;
  final VoidCallback? onPause, onModerate;
  final Future<bool> Function()? beforeHint;
  final String? error;
  final VoidCallback? onReport;
  const PictureChoiceBoard({
    this.onReport,
    super.key,
    required this.question,
    required this.feedback,
    required this.busy,
    required this.step,
    required this.total,
    required this.onAnswer,
    required this.onNext,
    this.onPause,
    this.onModerate,
    this.beforeHint,
    this.error,
  });
  @override
  Widget build(BuildContext context) {
    final images = List<Map<String, dynamic>>.from(
      (question.data['image_options'] as List).map(
        (x) => Map<String, dynamic>.from(x),
      ),
    );
    final order = JourneyOptionOrder.indices(context, images.length);
    final ids = List<String>.from(question.data['option_species']);
    final answered = feedback != null;
    return Scaffold(
      appBar: AppBar(
        title: Text('Mission jumelles · $step/$total'),
        leading: onPause == null
            ? null
            : IconButton(
                onPressed: busy ? null : onPause,
                icon: const Icon(Icons.close),
                tooltip: 'Mettre la balade en pause',
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
              onPressed: busy ? null : onModerate,
              icon: const Icon(Icons.flag_outlined),
              tooltip: 'Écarter cette question',
            ),
        ],
      ),
      body: GamePageBody(
        progress: step / total,
        children: [
          Row(
            children: [
              const Pio(size: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  question.prompt,
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    color: ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (error != null)
            Text(error!, style: const TextStyle(color: Colors.deepOrange)),
          LayoutBuilder(
            builder: (context, c) {
              final columns = c.maxWidth < 250 ? 1 : 2;
              final width = (c.maxWidth - (columns - 1) * 12) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: List.generate(images.length, (position) {
                  final i = order[position];
                  final correct = answered && i == question.answer;
                  final wrong =
                      answered && feedback!['choice'] == i && !correct;
                  return RetryChoice(
                    index: i,
                    child: SizedBox(
                      width: width,
                      child: Semantics(
                        button: true,
                        label: answered
                            ? question.options[i]
                            : 'Photo ${position + 1}',
                        child: Card(
                          clipBehavior: Clip.antiAlias,
                          color: correct
                              ? const Color(0xffdcf1d8)
                              : wrong
                              ? const Color(0xffffe2d7)
                              : gameButter,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              width: correct || wrong ? 3 : 1,
                              color: correct
                                  ? Colors.green
                                  : wrong
                                  ? Colors.deepOrange
                                  : const Color(0xffd1e8e5),
                            ),
                          ),
                          child: InkWell(
                            onTap: busy || answered ? null : () => onAnswer(i),
                            child: Column(
                              children: [
                                ExcludeSemantics(
                                  child: BirdPhoto(
                                    species: ids[i],
                                    media: images[i],
                                    height: (width * .75).clamp(100.0, 180.0),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Text(
                                    answered
                                        ? '${correct
                                              ? '✓ '
                                              : wrong
                                              ? '↪ '
                                              : ''}${question.options[i]}'
                                        : 'Photo ${position + 1}',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
          if (answered) ...[
            const SizedBox(height: 18),
            Text(
              feedback!['correct'] == true
                  ? 'Bien repéré !'
                  : 'Regarde la photo entourée de vert.',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Text(question.explanation, style: const TextStyle(fontSize: 17)),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: busy ? null : onNext,
              child: Text(busy ? 'Sauvegarde…' : 'Mission suivante'),
            ),
          ],
          if (!answered)
            NaturalistGuideButton(
              question: question,
              answered: answered,
              enabled: !busy,
              beforeHint: beforeHint,
            ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text('Crédits des photos'),
                content: SizedBox(
                  width: 500,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: List.generate(
                        images.length,
                        (position) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: SelectableText(
                            'Photo ${position + 1} — ${images[order[position]]['author']}\n${images[order[position]]['license']}\n${images[order[position]]['source']}\n${images[order[position]]['license_url']}\n${images[order[position]]['modifications'] ?? ''}',
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(c),
                    child: const Text('Fermer'),
                  ),
                ],
              ),
            ),
            child: const Text('Crédits des photos'),
          ),
        ],
      ),
    );
  }
}
