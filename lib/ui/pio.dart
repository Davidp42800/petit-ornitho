import 'package:flutter/material.dart';
import 'components.dart';

const pioStages = [
  'Tout juste éclos',
  'Petites ailes',
  'Curieux des jardins',
  'Petit explorateur',
  'Prêt à s’envoler',
];

/// Fictional companion only. Never used as a species-identification photograph.
/// The five forms depend on unlocked progression, not on purchases or daily use.
class Pio extends StatelessWidget {
  final int level;
  final double size;
  final bool guide;
  const Pio({super.key, this.level = 1, this.size = 112, this.guide = false});
  @override
  Widget build(BuildContext context) {
    final index = guide ? 5 : level.clamp(1, 5) - 1;
    return Semantics(
      label: guide ? 'Pépi, ton guide' : 'Pépi : ${pioStages[index]}',
      image: true,
      child: SizedBox(
        width: size,
        height: size,
        child: ClipRect(
          child: OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: size * 3,
            maxWidth: size * 3,
            minHeight: size * 2,
            maxHeight: size * 2,
            child: Transform.translate(
              offset: Offset(-(index % 3) * size, -(index ~/ 3) * size),
              child: Image.asset(
                'assets/art/pio-evolution-v1.png',
                width: size * 3,
                height: size * 2,
                fit: BoxFit.fill,
                excludeFromSemantics: true,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PioGreeting extends StatelessWidget {
  final int level;
  final String title, message;
  const PioGreeting({
    super.key,
    required this.level,
    required this.title,
    required this.message,
  });
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final stacked =
          constraints.maxWidth < 280 ||
          MediaQuery.textScalerOf(context).scale(14) > 20;
      final heading = Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: ink,
          height: 1.2,
        ),
      );
      final description = Text(
        message,
        style: const TextStyle(fontSize: 14, color: ink, height: 1.45),
      );
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xffd5f2ff), Color(0xffeefbf4)],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: stacked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Pio(level: level, size: 56),
                      const SizedBox(width: 12),
                      Expanded(child: heading),
                    ],
                  ),
                  const SizedBox(height: 8),
                  description,
                ],
              )
            : Row(
                children: [
                  Pio(level: level, size: 80),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        heading,
                        const SizedBox(height: 8),
                        description,
                      ],
                    ),
                  ),
                ],
              ),
      );
    },
  );
}

class PioGrowth extends StatelessWidget {
  final int level;
  const PioGrowth({super.key, required this.level});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xffe4f5ff),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pépi grandit avec toi',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: ink,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (var i = 1; i <= 5; i++)
              Expanded(
                child: Column(
                  children: [
                    Opacity(
                      opacity: i <= level ? 1 : .35,
                      child: LayoutBuilder(
                        builder: (_, c) =>
                            Pio(level: i, size: c.maxWidth.clamp(24, 70)),
                      ),
                    ),
                    Icon(
                      i < level
                          ? Icons.check_circle
                          : i == level
                          ? Icons.star_rounded
                          : Icons.lock_outline,
                      size: 20,
                      color: i <= level
                          ? const Color(0xff087a83)
                          : const Color(0xff6b8290),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Niveau ${level.clamp(1, 5)} · ${pioStages[level.clamp(1, 5) - 1]}',
          style: const TextStyle(fontWeight: FontWeight.w800, color: ink),
        ),
        const SizedBox(height: 4),
        Text(
          level < 5
              ? 'Complète les objectifs de ta balade sur plusieurs séries pour faire grandir Pépi.'
              : 'Pépi a déployé ses ailes. Continuez à découvrir ensemble !',
          style: const TextStyle(color: ink, height: 1.4),
        ),
      ],
    ),
  );
}
