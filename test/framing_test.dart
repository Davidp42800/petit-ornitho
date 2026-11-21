import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petit_ornitho/ui/bird_photo.dart';

void main() {
  testWidgets(
    'Une photo indisponible propose un seul rechargement accessible',
    (t) async {
      await t.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BirdPhoto(
              species: 'synthetic-missing',
              semanticLabel: 'Oiseau du test',
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.bySemanticsLabel('Recharger la photo'), findsOneWidget);
      await t.tap(find.text('Recharger la photo'));
      await t.pumpAndSettle();
      expect(find.bySemanticsLabel('Recharger la photo'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('Off-center goldfinch has balanced sharp-photo margins', (
    t,
  ) async {
    final boundary = GlobalKey();
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              key: boundary,
              child: const SizedBox(
                width: 512,
                child: BirdPhoto(species: 'goldfinch'),
              ),
            ),
          ),
        ),
      ),
    );
    await t.runAsync(
      () => precacheImage(
        const AssetImage('assets/birds/goldfinch.jpg'),
        boundary.currentContext!,
      ),
    );
    await t.pumpAndSettle();
    final crop = t
        .widgetList<ClipRect>(find.byType(ClipRect))
        .firstWhere((w) => w.clipper != null);
    final rect = crop.clipper!.getClip(const Size(512, 240));
    expect(rect.left, closeTo(512 - rect.right, .001));
    expect(rect.top, closeTo(240 - rect.bottom, .001));
    await t.runAsync(() async {
      final image =
          await (boundary.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File(
        '/private/tmp/ornitho-goldfinch-framing.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
  });

  test(
    'Every bird stays centered and entirely inside phone, card and desktop frames',
    () {
      for (final framing in birdFraming.values) {
        for (final viewport in [
          const Size(131, 131),
          const Size(342, 240),
          const Size(600, 230),
        ]) {
          final rect = framedImageRect(viewport, framing.size, framing.subject);
          final visibleSubject = Rect.fromLTRB(
            rect.left + framing.subject.left * rect.width,
            rect.top + framing.subject.top * rect.height,
            rect.left + framing.subject.right * rect.width,
            rect.top + framing.subject.bottom * rect.height,
          );
          expect(visibleSubject.center.dx, closeTo(viewport.width / 2, .001));
          expect(visibleSubject.center.dy, closeTo(viewport.height / 2, .001));
          expect(visibleSubject.left, greaterThanOrEqualTo(0));
          expect(visibleSubject.top, greaterThanOrEqualTo(0));
          expect(visibleSubject.right, lessThanOrEqualTo(viewport.width));
          expect(visibleSubject.bottom, lessThanOrEqualTo(viewport.height));
        }
      }
    },
  );
}
