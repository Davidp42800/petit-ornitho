import 'package:flutter/material.dart';

/// Decorative artwork only; identification photos stay independent.
class GardenBackdrop extends StatelessWidget {
  final Widget child;
  final bool illustrated;
  const GardenBackdrop({
    super.key,
    required this.child,
    this.illustrated = true,
  });

  @override
  Widget build(BuildContext context) => !illustrated
      ? ColoredBox(color: const Color(0xffdfeef2), child: child)
      : Stack(
          fit: StackFit.expand,
          children: [
            ExcludeSemantics(
              child: Image.asset(
                'assets/art/swiss-garden-v1.png',
                fit: BoxFit.cover,
                alignment: Alignment.center,
                errorBuilder: (_, _, _) =>
                    const ColoredBox(color: Color(0xff244a39)),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x60155770),
                    Color(0x10155770),
                    Color(0x30155770),
                  ],
                  stops: [0, .32, 1],
                ),
              ),
            ),
            child,
          ],
        );
}
