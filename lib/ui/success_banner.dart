import 'package:flutter/material.dart';

/// A decorative celebration; rewards and the next action stay on the board.
class SuccessBanner extends StatelessWidget {
  const SuccessBanner({super.key});
  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 380),
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xff154d5b), Color(0xff1a706b)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xffd7b967), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33183e54),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Color(0xffffe6a7),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Color(0xff154d5b),
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            const Flexible(
              child: Text(
                'Bravo !',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
