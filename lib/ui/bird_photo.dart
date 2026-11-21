import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

// Older question snapshots retain their original import path. Only reviewed
// media are shipped; resolving the path preserves those immutable snapshots.
String bundledBirdAsset(String asset) =>
    asset.startsWith('assets/birds/catalog/')
    ? asset.replaceFirst('assets/birds/catalog/', 'assets/birds/reviewed/')
    : asset;

/// Subject bounds, reviewed against each original photograph (not the canvas).
/// They include the head, bill, wings, legs and tail. The file stays unmodified.
const birdFraming = <String, ({Size size, Rect subject})>{
  'robin': (size: Size(1200, 868), subject: Rect.fromLTRB(0, .07, .73, .95)),
  'blackbird': (
    size: Size(1024, 683),
    subject: Rect.fromLTRB(0, .21, .77, .95),
  ),
  'blue_tit': (
    size: Size(1200, 800),
    subject: Rect.fromLTRB(.13, .12, .68, .93),
  ),
  'goldfinch': (
    size: Size(1200, 800),
    subject: Rect.fromLTRB(.10, 0, .53, .92),
  ),
};

Rect framedImageRect(Size viewport, Size image, Rect subject) {
  final scale = math.min(
    viewport.width / (image.width * subject.width * 1.12),
    viewport.height / (image.height * subject.height * 1.12),
  );
  return Rect.fromLTWH(
    viewport.width / 2 - subject.center.dx * image.width * scale,
    viewport.height / 2 - subject.center.dy * image.height * scale,
    image.width * scale,
    image.height * scale,
  );
}

class BirdPhoto extends StatelessWidget {
  final String species;
  final Map<String, dynamic>? media;
  final double height;
  final String? semanticLabel;
  const BirdPhoto({
    super.key,
    required this.species,
    this.media,
    this.height = 240,
    this.semanticLabel,
  });
  @override
  Widget build(BuildContext context) {
    final asset = bundledBirdAsset(
      media?['asset'] as String? ?? 'assets/birds/$species.jpg',
    );
    final bounds = media?['subject'] as List?;
    final dimensions = media?['dimensions'] as Map?;
    final framing = bounds != null && dimensions != null
        ? (
            size: Size(
              (dimensions['width'] as num).toDouble(),
              (dimensions['height'] as num).toDouble(),
            ),
            subject: Rect.fromLTRB(
              (bounds[0] as num).toDouble(),
              (bounds[1] as num).toDouble(),
              (bounds[2] as num).toDouble(),
              (bounds[3] as num).toDouble(),
            ),
          )
        : birdFraming[species] ??
              (
                size: const Size(1, 1),
                subject: const Rect.fromLTWH(0, 0, 1, 1),
              );
    return Semantics(
      label: semanticLabel,
      // Both image layers already exclude their decorative pixels. Keep the
      // retry button accessible if the foreground image fails to load.
      explicitChildNodes: true,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: LayoutBuilder(
          builder: (context, c) {
            final rect = framedImageRect(
              Size(c.maxWidth, height),
              framing.size,
              framing.subject,
            );
            final needsBackdrop =
                rect.left > 0 ||
                rect.top > 0 ||
                rect.right < c.maxWidth ||
                rect.bottom < height;
            return ColoredBox(
              color: const Color(0xff17382d),
              child: ClipRect(
                child: Stack(
                  children: [
                    if (needsBackdrop) ...[
                      Positioned.fill(
                        child: ImageFiltered(
                          imageFilter: ui.ImageFilter.blur(
                            sigmaX: 16,
                            sigmaY: 16,
                          ),
                          child: _RetryBirdImage(
                            asset: asset,
                            fit: BoxFit.cover,
                            background: true,
                          ),
                        ),
                      ),
                      const Positioned.fill(
                        child: ColoredBox(color: Color(0x550e231a)),
                      ),
                    ],
                    Positioned.fill(
                      child: ClipRect(
                        clipper: _CenteredPhotoClip(rect),
                        child: Stack(
                          children: [
                            Positioned.fromRect(
                              rect: rect,
                              child: _RetryBirdImage(
                                asset: asset,
                                fit: BoxFit.fill,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RetryBirdImage extends StatefulWidget {
  final String asset;
  final BoxFit fit;
  final bool background;
  const _RetryBirdImage({
    required this.asset,
    required this.fit,
    this.background = false,
  });
  @override
  State<_RetryBirdImage> createState() => _RetryBirdImageState();
}

class _RetryBirdImageState extends State<_RetryBirdImage> {
  int retry = 0;
  @override
  Widget build(BuildContext context) => Image.asset(
    widget.asset,
    key: ValueKey('${widget.asset}-$retry'),
    fit: widget.fit,
    excludeFromSemantics: true,
    errorBuilder: (context, error, stack) => widget.background
        ? const SizedBox.shrink()
        : Center(
            child: TextButton.icon(
              onPressed: () async {
                await AssetImage(widget.asset).evict();
                if (mounted) setState(() => retry++);
              },
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: const Text(
                'Recharger la photo',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
  );
}

/// Keep the sharp photograph symmetric around the centered subject. Without
/// this crop an off-center bird leaves one large blurred margin and one narrow
/// margin, making the entire photograph appear shifted.
class _CenteredPhotoClip extends CustomClipper<Rect> {
  final Rect imageRect;
  const _CenteredPhotoClip(this.imageRect);
  @override
  Rect getClip(Size size) {
    final horizontal = math.max(
      0.0,
      math.max(imageRect.left, size.width - imageRect.right),
    );
    final vertical = math.max(
      0.0,
      math.max(imageRect.top, size.height - imageRect.bottom),
    );
    return Rect.fromLTRB(
      horizontal,
      vertical,
      size.width - horizontal,
      size.height - vertical,
    );
  }

  @override
  bool shouldReclip(_CenteredPhotoClip old) => old.imageRect != imageRect;
}
