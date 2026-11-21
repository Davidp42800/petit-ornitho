import 'package:flutter/material.dart';
import 'components.dart';
import 'pio.dart';

class PepiHintButton extends StatelessWidget {
  final String label;
  final bool photo;
  final bool guide;
  final VoidCallback? onPressed;
  const PepiHintButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.photo = false,
    this.guide = false,
  });
  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      foregroundColor: ink,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: Opacity(
            opacity: onPressed == null ? .45 : 1,
            child: SizedBox(
              width: 78,
              height: 66,
              child: Stack(
                children: [
                  const Positioned(
                    left: 0,
                    top: 0,
                    child: Pio(level: 3, size: 64),
                  ),
                  Positioned(
                    right: 3,
                    bottom: 4,
                    child: Transform.rotate(
                      angle: -.12,
                      child: Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: photo
                              ? const Color(0xffbfe5d8)
                              : const Color(0xffffdf84),
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x33405c72),
                              offset: Offset(0, 2),
                              blurRadius: 3,
                            ),
                          ],
                        ),
                        child: guide
                            ? const Icon(
                                Icons.search_rounded,
                                size: 23,
                                color: ink,
                              )
                            : photo
                            ? const Icon(
                                Icons.photo_camera_rounded,
                                size: 23,
                                color: ink,
                              )
                            : const Text(
                                'A',
                                style: TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w900,
                                  color: ink,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}
