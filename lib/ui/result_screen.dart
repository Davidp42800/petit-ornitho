import '../domain/chapter_progress.dart';
import 'chapter_objectives.dart';
import 'package:flutter/material.dart';
import 'components.dart';
import 'garden_backdrop.dart';
import 'quest_materials.dart';
import 'pio.dart';

class ResultScreen extends StatelessWidget {
  final Map<String, dynamic> result;
  final int companionLevel;
  final bool companionGrew;
  const ResultScreen({
    super.key,
    required this.result,
    this.companionLevel = 1,
    this.companionGrew = false,
  });
  @override
  Widget build(BuildContext c) => Scaffold(
    body: GardenBackdrop(
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(MediaQuery.sizeOf(c).width < 360 ? 16 : 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: FieldPaper(
                child: Column(
                  children: [
                    Pio(level: companionLevel, size: 180),
                    if (companionGrew)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text(
                          'Pépi a grandi grâce à toi !',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: green,
                            fontWeight: FontWeight.w900,
                            fontSize: 21,
                          ),
                        ),
                      ),
                    const SizedBox(height: 28),
                    if (result['unlocked_pack'] case final Map pack) ...[
                      const Icon(
                        Icons.lock_open_rounded,
                        color: green,
                        size: 42,
                      ),
                      Text(
                        'Bravo ! Tu as débloqué :\n${pack['label']}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: green,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${pack['count']} nouvelles espèces à découvrir.\n${pack['photo_species']} espèces illustrées rejoignent les jeux photo.',
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        (pack['audio_species'] ?? 0) > 0
                            ? '${pack['audio_species']} nouveaux oiseaux à reconnaître au chant !'
                            : 'Les chants de ces oiseaux sont encore en préparation.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                    ],
                    const Text(
                      'Une belle envolée !',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      result['correct'] >=
                              ((result['total'] as int) * 2 / 3).ceil()
                          ? 'Balade réussie. Ton regard s’aiguise !'
                          : 'Chaque découverte compte. Rejoue pour réussir au moins deux tiers des défis.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 17,
                        height: 1.5,
                        color: muted,
                      ),
                    ),
                    if (result['recap'] case final List recap)
                      for (final (label, correct, assisted) in const [
                        ('Défis réussis sans aide', true, false),
                        ('Défis réussis avec aide', true, true),
                        ('Défis à revoir', false, null),
                      ])
                        if (recap
                                .whereType<Map>()
                                .where(
                                  (row) =>
                                      row['correct'] == correct &&
                                      (assisted == null ||
                                          row['assisted'] == assisted),
                                )
                                .map((row) => row['name'])
                                .whereType<String>()
                                .toSet()
                            case final names when names.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: ListTile(
                              title: Text(label),
                              subtitle: Text(names.join(' · ')),
                            ),
                          ),
                    if (result['chapter_objectives'] case final Map objectives)
                      ChapterObjectives(
                        progress: ChapterProgress.fromJson(objectives),
                        audioAvailable: result['audio_available'] == true,
                      ),
                    if (companionLevel >= 5) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Tu explores les défis Expert. Le titre demandera une '
                        'maîtrise vérifiée des photos, des chants et des connaissances '
                        'de toutes les espèces, sur plusieurs séances.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 32),
                    StatPair(
                      first: Stat(
                        value: '+${result['score']}',
                        label: 'plumes gagnées',
                      ),
                      second: Stat(
                        value: '${result['correct']}/${result['total']}',
                        label: 'bonnes réponses',
                      ),
                    ),
                    const SizedBox(height: 32),
                    FilledButton(
                      onPressed: () => Navigator.pop(c),
                      child: const Text('Retrouver mon parcours →'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
