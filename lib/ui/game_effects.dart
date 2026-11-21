import 'success_banner.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'letter_delivery.dart';

/// Shared feedback for every game. Finite, silent, and never intercepts taps.
class GameEffects extends StatefulWidget {
  final Widget child;
  final Object? event;
  final bool success;
  final VoidCallback? onKeepReading, onContinue;
  final bool readingPaused;
  const GameEffects({
    super.key,
    required this.child,
    required this.event,
    required this.success,
    this.onKeepReading,
    this.onContinue,
    this.readingPaused = false,
  });
  @override
  State<GameEffects> createState() => _GameEffectsState();
}

class _GameEffectsState extends State<GameEffects>
    with SingleTickerProviderStateMixin {
  late final AnimationController motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3000),
  );
  bool initialized = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      motion.stop();
      motion.value = 1;
    } else if (!initialized && widget.event != null) {
      motion.forward(from: 0);
    }
    initialized = true;
  }

  @override
  void didUpdateWidget(GameEffects old) {
    super.didUpdateWidget(old);
    if (old.event != widget.event) {
      if (widget.event == null || MediaQuery.disableAnimationsOf(context)) {
        motion.stop();
        motion.value = 1;
      } else {
        motion.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      widget.child,
      Positioned.fill(
        child: IgnorePointer(
          child: ExcludeSemantics(
            child: AnimatedBuilder(
              animation: motion,
              builder: (context, _) {
                if (widget.event == null ||
                    motion.value >= 1 ||
                    MediaQuery.disableAnimationsOf(context)) {
                  return const SizedBox.shrink();
                }
                return LayoutBuilder(
                  builder: (context, c) {
                    final t = motion.value;
                    final fade = (math.sin(t * math.pi) * 1.5).clamp(0.0, 1.0);
                    final rise = Curves.easeOutCubic.transform(
                      (t / .4).clamp(0.0, 1.0),
                    );
                    return Opacity(
                      opacity: fade,
                      child: Stack(
                        children: [
                          if (widget.success)
                            Positioned.fill(
                              child: CustomPaint(painter: _FeatherSparkles(t)),
                            ),
                          for (final side
                              in widget.success
                                  ? [-4, -3, -2, -1, 1, 2, 3, 4]
                                  : [1])
                            Positioned(
                              left: side < 0
                                  ? -70 + rise * (c.maxWidth * .2 + 70)
                                  : c.maxWidth - rise * (c.maxWidth * .2 + 70),
                              top:
                                  c.maxHeight * (.16 + side.abs() * .09) -
                                  40 * math.sin(t * math.pi + side.abs() * .7),
                              child: Transform.rotate(
                                angle: math.sin(t * math.pi * 8) * .1 * side,
                                child: Transform.scale(
                                  scale: .8 + .2 * math.sin(t * math.pi),
                                  child: FlyingPio(
                                    size: widget.success
                                        ? 48 + side.abs() * 6.0
                                        : 68,
                                    phase: t * 3 + side.abs() * .15,
                                    variant: side,
                                  ),
                                ),
                              ),
                            ),
                          if (widget.success)
                            Positioned(
                              top: 12,
                              left: 20,
                              right: 20,
                              child: Center(
                                child: Transform.scale(
                                  scale:
                                      .85 +
                                      .15 *
                                          Curves.easeOutBack.transform(
                                            (t / .25).clamp(0.0, 1.0),
                                          ),
                                  child: const SuccessBanner(),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
      if (onReadingAvailable)
        Positioned(
          bottom: 12,
          left: 16,
          right: 16,
          child: SafeArea(
            top: false,
            child: FilledButton.icon(
              onPressed: widget.onContinue,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Suivant'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ),
        ),
    ],
  );
  bool get onReadingAvailable => widget.success && widget.onKeepReading != null;
}

class _FeatherSparkles extends CustomPainter {
  final double t;
  _FeatherSparkles(this.t);
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * .28);
    const colors = [
      Color(0xffffcf69),
      Color(0xffa6dcc7),
      Color(0xffc8b5ef),
      Color(0xffa4d5ed),
    ];
    for (var i = 0; i < 48; i++) {
      final angle = i * math.pi * 2 / 48;
      final distance = (22 + t * size.width * .43) * (i.isEven ? 1 : .7);
      final point =
          center +
          Offset(
            math.cos(angle) * distance,
            math.sin(angle) * distance * .65 + t * t * 80,
          );
      final p = Paint()..color = colors[i % colors.length];
      canvas.save();
      canvas.translate(point.dx, point.dy);
      canvas.rotate(angle + t * 3);
      if (i % 3 == 0) {
        final path = Path()
          ..moveTo(0, -7)
          ..quadraticBezierTo(2, -2, 7, 0)
          ..quadraticBezierTo(2, 2, 0, 7)
          ..quadraticBezierTo(-2, 2, -7, 0)
          ..quadraticBezierTo(-2, -2, 0, -7)
          ..close();
        canvas.drawPath(path, p);
      } else if (i % 3 == 1) {
        final ribbon = Path()
          ..moveTo(0, -12)
          ..cubicTo(9, -7, -9, 1, 0, 6)
          ..quadraticBezierTo(8, 11, 0, 16);
        canvas.drawPath(
          ribbon,
          Paint()
            ..color = colors[i % colors.length]
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round,
        );
      } else {
        canvas.drawOval(const Rect.fromLTWH(-3, -6, 6, 12), p);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_FeatherSparkles old) => old.t != t;
}
