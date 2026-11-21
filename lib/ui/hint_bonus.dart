import 'package:flutter/material.dart';
import 'components.dart';

/// A tactile bonus card; its callback still acknowledges assistance first.
class HintBonus extends StatelessWidget {
  final String title, label;
  final IconData icon;
  final bool photo;
  final VoidCallback? onPressed;
  const HintBonus({super.key, required this.title, required this.label,
    required this.icon, required this.onPressed, this.photo = false});

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final tint = photo ? const Color(0xffd7eee5) : const Color(0xffffe6a7);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: enabled ? [BoxShadow(
            color: photo ? const Color(0xff8fbbaa) : const Color(0xffcfb36a),
            offset: const Offset(0, 4),
          )] : [],
        ),
        child: Material(
          color: enabled ? tint : const Color(0xffe8eded),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: enabled ? Colors.white : const Color(0xffcddbd8), width: 2)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(children: [
                Container(width: 44, height: 44,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: .65),
                    borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: ink, size: 28)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(color: ink, fontWeight: FontWeight.w900, fontSize: 17)),
                  Text(label, style: const TextStyle(color: ink, fontSize: 13)),
                ])),
                const SizedBox(width: 8),
                Icon(enabled ? Icons.auto_awesome : Icons.lock_outline, size: 20, color: ink),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
