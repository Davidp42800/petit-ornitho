import 'package:flutter/material.dart';
import 'components.dart';
import 'pio.dart';

/// One clear entry into the saved journey; no new progression rules.
class JourneyHero extends StatelessWidget {
  final String place, detail;
  final int level;
  final bool resuming, busy;
  final VoidCallback onStart;
  const JourneyHero({
    super.key,
    required this.place,
    required this.detail,
    required this.level,
    required this.resuming,
    required this.busy,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xffd9f1f7), Color(0xffedf8f1)],
      ),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xffb6dce3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          resuming ? 'TA BALADE EN COURS' : 'TA PROCHAINE BALADE',
          style: const TextStyle(
            color: green,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: .8,
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final title = Text(
              place,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: ink,
                height: 1.15,
              ),
            );
            if (constraints.maxWidth < 260 ||
                MediaQuery.textScalerOf(context).scale(16) > 22) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Pio(level: level, size: 64),
                  const SizedBox(height: 8),
                  title,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: title),
                const SizedBox(width: 12),
                Pio(level: level, size: 80),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        Text(detail, style: const TextStyle(color: ink, height: 1.4)),
        const SizedBox(height: 12),
        const Text(
          'Observe, écoute et avance à ton rythme.',
          style: TextStyle(color: muted, height: 1.4),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: busy ? null : onStart,
          child: Text(
            busy
                ? 'Préparation…'
                : resuming
                ? 'Reprendre ma balade'
                : 'Commencer ma balade →',
            textAlign: TextAlign.center,
          ),
        ),
      ],
    ),
  );
}
