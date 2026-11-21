import 'journey_option_order.dart';
import 'package:flutter/material.dart';
import '../domain/decisive_criterion.dart';
import '../domain/game.dart';
import 'components.dart';
import 'garden_backdrop.dart';
import 'pio.dart';
import 'quest_materials.dart';
import 'retry_feedback.dart';

/// A source-backed observation followed by a distinct justification gesture.
class CriterionBoard extends StatelessWidget {
  final Question question;
  final DecisiveCriterion progress;
  final List<Map<String, dynamic>> facts;
  final Map<String, dynamic>? feedback;
  final bool busy;
  final String? error;
  final int step, total, score;
  final void Function(CriterionPhase, int) onAnswer;
  final VoidCallback onPause, onNext;
  final VoidCallback? onReport;
  const CriterionBoard({
    this.onReport,
    super.key,
    required this.question,
    required this.progress,
    required this.facts,
    required this.feedback,
    required this.busy,
    required this.step,
    required this.total,
    required this.score,
    required this.onAnswer,
    required this.onPause,
    required this.onNext,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    final phase = progress.phase(question.data);
    final done = phase == null;
    final part = phase == CriterionPhase.justification
        ? question.data['justification'] as Map
        : question.data;
    final wrong = phase == null
        ? <int>{}
        : progress.choices(phase).where((i) => i != part['answer']).toSet();
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Mettre la balade en pause',
            onPressed: busy ? null : onPause,
            icon: const Icon(Icons.close),
          ),
          title: Text(
            'MA BALADE · $step/$total',
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            if (onReport != null)
              IconButton(
                tooltip: 'Signaler cette question',
                icon: const Icon(Icons.feedback_outlined),
                onPressed: busy ? null : onReport,
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Center(child: Text('$score plumes')),
            ),
          ],
        ),
        body: GardenBackdrop(
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: ListView(
                  key: ValueKey("${question.id}:${phase?.name ?? 'result'}"),
                  padding: const EdgeInsets.all(20),
                  children: [
                    LinearProgressIndicator(
                      value: step / total,
                      semanticsLabel: 'Défi $step sur $total',
                    ),
                    const SizedBox(height: 16),
                    FieldPaper(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Row(
                            children: [
                              Pio(level: 5, size: 46),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Le détail qui change tout',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: ink,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            question.prompt,
                            style: const TextStyle(
                              fontSize: 18,
                              height: 1.5,
                              color: ink,
                            ),
                          ),
                          const SizedBox(height: 20),
                          if (!done) ...[
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                phase == CriterionPhase.identification
                                    ? '1 · Quel oiseau ?'
                                    : '2 · Quel détail fait la différence ?',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: ink,
                                ),
                              ),
                            ),
                            if (phase == CriterionPhase.justification) ...[
                              const SizedBox(height: 10),
                              Text(
                                'Oiseau identifié : ${question.options[question.answer]}',
                                style: const TextStyle(color: green),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                part['prompt'] as String,
                                style: const TextStyle(
                                  fontSize: 18,
                                  color: ink,
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            RetryFeedback(
                              wrong: wrong,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (final i in JourneyOptionOrder.indices(context, (part['options'] as List).length, phase.name))
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 10,
                                      ),
                                      child: RetryChoice(
                                        key: ValueKey('${phase.name}:$i'),
                                        index: i,
                                        child: QuestButton(
                                          pastelColor: const Color(0xfff8edcf),
                                          onPressed: busy || wrong.contains(i)
                                              ? null
                                              : () => onAnswer(phase, i),
                                          child: Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(16),
                                            child: Text(
                                              part['options'][i] as String,
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w600,
                                                color: ink,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (wrong.isNotEmpty)
                              const Text(
                                'Ce choix ne correspond pas. Compare les autres propositions.',
                                style: TextStyle(color: ink),
                              ),
                          ] else ...[
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                feedback?['correct'] == true
                                    ? 'Bien observé et bien expliqué !'
                                    : 'Tu as retrouvé le bon détail !',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: green,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              question.explanation,
                              style: const TextStyle(
                                fontSize: 18,
                                height: 1.5,
                                color: ink,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              question.data['justification']['explanation']
                                  as String,
                              style: const TextStyle(
                                fontSize: 18,
                                height: 1.5,
                                color: ink,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '+${feedback?['points'] ?? 0} plumes',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: green,
                              ),
                            ),
                            if (feedback?['correct'] == false)
                              const Text(
                                'Défi corrigé : les premières réponses restent enregistrées.',
                                style: TextStyle(color: muted),
                              ),
                            for (final fact in facts)
                              TextButton.icon(
                                onPressed: () => sourceDialog(
                                  context,
                                  fact['source_url'] as String,
                                  fact['publisher'] as String,
                                  null,
                                ),
                                icon: const Icon(Icons.menu_book_outlined),
                                label: Text(
                                  '${fact['document_title']} · ${fact['section']}',
                                ),
                              ),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: busy ? null : onNext,
                              child: const Text('Poursuivre ma balade'),
                            ),
                          ],
                          if (busy) const LinearProgressIndicator(),
                          if (error != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Semantics(
                                liveRegion: true,
                                child: Text(
                                  error!,
                                  style: const TextStyle(color: Colors.red),
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
    );
  }
}
