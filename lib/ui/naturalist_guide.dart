import 'pepi_hint_button.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/game.dart';
import 'components.dart';
import 'pio.dart';

String guideHint(Question q) {
  if (q.kind == 'photo') {
    return q.data['_ecology']?['text'] as String? ??
        'Je n’ai pas encore d’indice complémentaire vérifié pour cet oiseau.';
  }
  final hint = q.data['hint'];
  if (hint is String && hint.trim().isNotEmpty) {
    return hint.replaceAll('Pio', 'Pépi');
  }
  if (q.clues.isNotEmpty) return q.clues.last;
  return switch (q.kind) {
    'photo' =>
      'Observe la tête, la poitrine et le bec. Compare leurs couleurs avant de choisir un nom.',
    'match' =>
      'Relis le détail décrit dans l’indice. Cherche ce détail sur les photos proposées.',
    'mystery' =>
      'Compare les indices déjà dévoilés. Tu peux utiliser « Un indice de plus » si tu hésites.',
    _ =>
      'Prends le temps de relire : parle-t-on d’un adulte, d’un jeune, de son plumage ou de sa nourriture ?',
  };
}

typedef GuideLoader =
    Future<Map<String, dynamic>> Function(String questionId, String mode);
Future<Map<String, dynamic>> loadGuide(String questionId, String mode) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null || user.isAnonymous) return {};
  final result = await Supabase.instance.client.functions
      .invoke(
        'naturalist-guide',
        body: {'question_id': questionId, 'mode': mode},
      )
      .timeout(const Duration(seconds: 20));
  if (Supabase.instance.client.auth.currentUser?.id != user.id) return {};
  return Map<String, dynamic>.from(result.data);
}

Future<void> showNaturalistGuide(
  BuildContext context,
  Question question,
  bool answered, {
  GuideLoader? loader,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: const Color(0xfff5f8f3),
  builder: (_) => _GuideSheet(
    question: question,
    answered: answered,
    loader: loader ?? loadGuide,
  ),
);

/// Optional help, independent from scoring. No free text or player data is sent.
class NaturalistGuideButton extends StatelessWidget {
  final Question question;
  final bool answered;
  final bool enabled;
  final bool pastel;
  final GuideLoader? loader;
  final Future<bool> Function()? beforeHint;
  const NaturalistGuideButton({
    super.key,
    required this.question,
    required this.answered,
    this.enabled = true,
    this.pastel = false,
    this.loader,
    this.beforeHint,
  });
  @override
  Widget build(BuildContext context) => PepiHintButton(
    guide: true,
    label: answered ? 'Explique-moi' : 'Aide de Pépi',
    onPressed: !enabled
        ? null
        : () async {
            if (!answered && beforeHint != null && !await beforeHint!()) return;
            if (!context.mounted) return;
            if (!answered) question.data['_hint_used'] = true;
            await showNaturalistGuide(
              context,
              question,
              answered,
              loader: loader,
            );
          },
  );
}

class _GuideSheet extends StatefulWidget {
  final Question question;
  final bool answered;
  final GuideLoader loader;
  const _GuideSheet({
    required this.question,
    required this.answered,
    required this.loader,
  });
  @override
  State<_GuideSheet> createState() => _GuideSheetState();
}

class _GuideSheetState extends State<_GuideSheet> {
  bool loading = true;
  bool ai = false;
  late String message = widget.answered
      ? widget.question.explanation
      : guideHint(widget.question);
  @override
  void initState() {
    super.initState();
    fetch();
  }

  Future<void> fetch() async {
    if (!widget.answered && widget.question.kind == 'photo') {
      setState(() => loading = false);
      return;
    }
    try {
      final result = await widget
          .loader(widget.question.id, widget.answered ? 'explain' : 'hint')
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      final text = result['message'];
      if (text is String && text.trim().isNotEmpty && text.length <= 420) {
        setState(() {
          message = text.replaceAll('Pio', 'Pépi');
          ai = result['origin'] == 'ai';
        });
      }
    } catch (_) {
      // Curated help is already visible, including offline and timeouts.
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Pio(guide: true, size: 74),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Pépi, ton guide',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: ink,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Fermer le guide',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Semantics(
            liveRegion: true,
            child: Text(
              message,
              style: const TextStyle(fontSize: 19, height: 1.5, color: ink),
            ),
          ),
          const SizedBox(height: 16),
          if (loading) const LinearProgressIndicator(minHeight: 3),
          const SizedBox(height: 8),
          Text(
            loading
                ? 'Le guide prépare son conseil…'
                : ai
                ? 'Conseil reformulé avec l’IA à partir du contenu du jeu.'
                : 'Conseil du carnet · disponible aussi hors connexion.',
            style: const TextStyle(fontSize: 12, color: muted),
          ),
          if (widget.answered || widget.question.data['_ecology'] != null)
            TextButton(
              onPressed: () => sourceDialog(
                context,
                widget.answered
                    ? widget.question.data['source']
                    : widget.question.data['_ecology']?['source'],
                widget.answered
                    ? widget.question.data['publisher']
                    : widget.question.data['_ecology']?['publisher'],
                null,
              ),
              child: const Text('Voir la source scientifique ↗'),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('À moi de jouer !'),
            ),
          ),
        ],
      ),
    ),
  );
}
