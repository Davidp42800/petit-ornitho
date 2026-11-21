import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'pio.dart';

/// A short, non-interactive reward. The answer changes only on landing.
class LetterDelivery extends StatefulWidget {
  final String letter;
  final Offset Function() target;
  final VoidCallback onDeposit, onDone;
  const LetterDelivery({
    super.key,
    required this.letter,
    required this.target,
    required this.onDeposit,
    required this.onDone,
  });
  @override
  State<LetterDelivery> createState() => _LetterDeliveryState();
}

class _LetterDeliveryState extends State<LetterDelivery>
    with SingleTickerProviderStateMixin {
  late final AnimationController flight = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1350),
  );
  bool deposited = false;
  @override
  void initState() {
    super.initState();
    flight.addListener(() {
      if (!deposited && flight.value >= .64) {
        deposited = true;
        widget.onDeposit();
      }
    });
    flight.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onDone();
    });
    flight.forward();
  }

  @override
  void dispose() {
    flight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: AnimatedBuilder(
        animation: flight,
        builder: (context, _) => LayoutBuilder(
          builder: (context, constraints) {
            final t = flight.value;
            final target = widget.target();
            final size = constraints.biggest;
            final arrival = Curves.easeInOutCubic.transform(
              (t / .64).clamp(0, 1),
            );
            final departure = Curves.easeInCubic.transform(
              ((t - .72) / .28).clamp(0, 1),
            );
            final birds = <Widget>[];
            for (var i = 0; i < 3; i++) {
              final escort = i != 0;
              final start = Offset(
                i == 2 ? size.width + 80 : -90,
                math.max(70, target.dy - 160 + i * 55),
              );
              final landing =
                  target +
                  Offset(
                    i == 1
                        ? -55
                        : i == 2
                        ? 55
                        : 0,
                    escort ? -62 : -48,
                  );
              final curve = Offset(
                (start.dx + landing.dx) / 2,
                math.max(30, math.min(start.dy, landing.dy) - 95),
              );
              final p =
                  start * ((1 - arrival) * (1 - arrival)) +
                  curve * (2 * (1 - arrival) * arrival) +
                  landing * (arrival * arrival);
              final end = Offset(
                i == 1 ? -110 : size.width + 110,
                math.max(0, target.dy - 230),
              );
              final position = Offset.lerp(p, end, departure)!;
              final flutter = math.sin(t * math.pi * 20 + i) * 3;
              final birdSize = escort ? 48.0 : 68.0;
              birds.add(
                Positioned(
                  left: position.dx - birdSize / 2,
                  top: position.dy - birdSize / 2 + flutter,
                  child: Transform.rotate(
                    angle: math.sin(t * math.pi * 4 + i) * .12,
                    child: FlyingPio(size: birdSize, phase: t, variant: i),
                  ),
                ),
              );
              if (!escort && t < .64) {
                birds.add(
                  Positioned(
                    left: position.dx - 16,
                    top: position.dy + 30 + flutter,
                    child: Container(
                      width: 32,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xffffdf84),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33405c72),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        widget.letter,
                        style: const TextStyle(
                          fontSize: 23,
                          fontFamily: 'Roboto',
                          decoration: TextDecoration.none,
                          fontWeight: FontWeight.w900,
                          color: Color(0xff294e5b),
                        ),
                      ),
                    ),
                  ),
                );
              }
            }
            final sparkle = ((t - .61) / .35).clamp(0.0, 1.0);
            return Stack(
              clipBehavior: Clip.none,
              children: [
                if (t > .61)
                  for (var i = 0; i < 8; i++)
                    Positioned(
                      left:
                          target.dx +
                          math.cos(i * math.pi / 4) * (12 + sparkle * 46) -
                          7,
                      top:
                          target.dy +
                          math.sin(i * math.pi / 4) * (12 + sparkle * 46) -
                          7,
                      child: Opacity(
                        opacity: 1 - sparkle,
                        child: Transform.rotate(
                          angle: sparkle * 2,
                          child: Icon(
                            Icons.auto_awesome,
                            size: 14,
                            color: i.isEven
                                ? const Color(0xffedae39)
                                : const Color(0xff7dc5d1),
                          ),
                        ),
                      ),
                    ),
                ...birds,
              ],
            );
          },
        ),
      ),
    ),
  );
}

class _Wings extends CustomPainter {
  final double t;
  final int offset;
  _Wings(this.t, this.offset);
  @override
  void paint(Canvas canvas, Size size) {
    final flap = math.sin(t * math.pi * 22 + offset);
    final paint = Paint()..color = const Color(0xffffecc0);
    for (final side in [-1, 1]) {
      canvas.save();
      canvas.translate(size.width / 2, size.height * .5);
      canvas.scale(side.toDouble(), 1);
      canvas.rotate(-.35 + flap * .65);
      final path = Path()
        ..moveTo(4, 0)
        ..quadraticBezierTo(
          size.width * .25,
          -size.height * .75,
          size.width * .49,
          -size.height * .1,
        )
        ..quadraticBezierTo(size.width * .37, size.height * .4, 4, 8)
        ..close();
      canvas.drawPath(path, paint);
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xffdeb983)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_Wings oldDelegate) => oldDelegate.t != t;
}

/// The same wingbeat is used by hints and game celebrations.
class FlyingPio extends StatelessWidget {
  final double size, phase;
  final int variant;
  const FlyingPio({
    super.key,
    required this.size,
    required this.phase,
    this.variant = 0,
  });
  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: -size * .25,
          top: size * .25,
          child: CustomPaint(
            size: Size(size * 1.5, size * .5),
            painter: _Wings(phase, variant),
          ),
        ),
        Pio(level: 1, size: size),
      ],
    ),
  );
}
