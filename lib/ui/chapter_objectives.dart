import 'package:flutter/material.dart';
import '../domain/chapter_progress.dart';
import 'components.dart';

class ChapterObjectives extends StatelessWidget {
  final ChapterProgress progress;
  final bool audioAvailable;
  final bool compact;
  const ChapterObjectives({
    super.key,
    required this.progress,
    this.audioAvailable = false,
    this.compact = false,
  });
  static const labels = {
    'sessions': 'Séries avec au moins 80 % de réponses sans aide',
    'correct': 'Bonnes réponses sans aide',
    'species': 'Espèces reconnues',
    'visual': 'Photos différentes reconnues',
    'knowledge': 'Faits différents compris',
    'audio': 'Extraits sonores différents reconnus',
  };
  static const badges = {
    'visual': ('Œil de lynx', Icons.visibility_outlined, Color(0xffdcecf7)),
    'correct': ('Détective', Icons.search_rounded, Color(0xffffe6ae)),
    'species': ('Explorateur', Icons.explore_outlined, Color(0xffd5ebe0)),
    'sessions': ('As de la balade', Icons.stars_rounded, Color(0xffe8dff3)),
    'knowledge': ('Esprit curieux', Icons.lightbulb_outline, Color(0xffffe0ce)),
    'audio': ('Oreille d’or', Icons.music_note_rounded, Color(0xffd7eeea)),
  };
  @override
  Widget build(BuildContext context) {
    final entries = progress.required.entries
        .where((e) => e.value > 0)
        .toList();
    if (entries.isEmpty) return const SizedBox.shrink();
    final won = entries
        .where((e) => (progress.counts[e.key] ?? 0) >= e.value)
        .length;
    if (compact) {
      return Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          title: const Text(
            'Les objectifs de ta balade',
            style: TextStyle(fontWeight: FontWeight.w700, color: ink),
          ),
          subtitle: Text(
            '$won / ${entries.length} badges gagnés · Voir les détails',
            style: const TextStyle(color: muted),
          ),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape: const Border(),
          collapsedShape: const Border(),
          children: [
            ChapterObjectives(
              progress: progress,
              audioAvailable: audioAvailable,
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Tes badges d’aventure',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    color: ink,
                  ),
                ),
              ),
              Text(
                '$won / ${entries.length}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            progress.ready
                ? 'Tous gagnés ! La suite t’attend.'
                : 'Gagne ces badges pour ouvrir la prochaine balade.',
            style: const TextStyle(color: ink),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, c) => Wrap(
              spacing: 12,
              runSpacing: 14,
              children: [
                for (final e in entries)
                  SizedBox(
                    width: c.maxWidth < 320
                        ? c.maxWidth
                        : (c.maxWidth - 12) / 2,
                    child: _badge(e),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Les réponses trouvées sans indice font grandir tes badges.',
            style: TextStyle(fontSize: 12, color: muted),
          ),
        ],
      ),
    );
  }

  Widget _badge(MapEntry<String, int> e) {
    final badge = badges[e.key]!;
    final count = (progress.counts[e.key] ?? 0).clamp(0, e.value);
    final done = count >= e.value;
    return Semantics(
      label:
          '${badge.$1}. ${labels[e.key]} : $count sur ${e.value}${done ? ", badge gagné" : ""}',
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: badge.$3,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [
            BoxShadow(color: Color(0xffbbd0d4), offset: Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Color(0xbbffffff),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(badge.$2, size: 26, color: ink),
                ),
                const Spacer(),
                if (done)
                  const Icon(
                    Icons.workspace_premium,
                    color: Color(0xff936715),
                    size: 30,
                  )
                else
                  Text(
                    '$count/${e.value}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: ink,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              badge.$1,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              done
                  ? 'Badge gagné !'
                  : e.key == 'sessions'
                  ? 'Réussis ${e.value} séries à 80 % sans aide'
                  : labels[e.key]!,
              style: const TextStyle(fontSize: 12, color: ink),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: count / e.value,
              minHeight: 7,
              borderRadius: BorderRadius.circular(8),
              backgroundColor: Colors.white70,
              color: green,
            ),
            if (e.key == 'audio' && !audioAvailable)
              const Text(
                'Sons en préparation',
                style: TextStyle(fontSize: 12, color: ink),
              ),
          ],
        ),
      ),
    );
  }
}
