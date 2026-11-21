import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petit_ornitho/ui/bird_photo.dart';

void main() {
  test(
    'Reviewed mountain and beginner subjects fit landscape and portrait game frames',
    () {
      final selected =
          jsonDecode(
                File(
                  'data/editorial/mountain-photo-selections.json',
                ).readAsStringSync(),
              )
              as Map;
      selected.addAll(
        jsonDecode(
              File(
                'data/editorial/level-one-photo-selections.json',
              ).readAsStringSync(),
            )
            as Map,
      );
      selected.addAll(
        jsonDecode(
              File(
                'data/editorial/beginner-photo-second-selections.json',
              ).readAsStringSync(),
            )
            as Map,
      );
      selected.addAll(
        jsonDecode(
              File(
                'data/editorial/beginner-photo-third-selections.json',
              ).readAsStringSync(),
            )
            as Map,
      );
      selected.addAll(
        jsonDecode(
              File(
                'data/editorial/beginner-photo-fourth-selections.json',
              ).readAsStringSync(),
            )
            as Map,
      );
      selected.addAll(jsonDecode(File("data/editorial/first-missing-photo-selections.json").readAsStringSync()) as Map);
      selected.addAll(jsonDecode(File("data/editorial/level-two-first-photo-selections.json").readAsStringSync()) as Map);
      selected.addAll(jsonDecode(File('data/editorial/level-two-second-photo-selections.json').readAsStringSync()) as Map);
      final birds =
          // Every release is covered by the same portrait/landscape invariant.
          jsonDecode(
                File('assets/data/photo_catalog.json').readAsStringSync(),
              )['species']
              as List;
      final photos = birds
          .expand((b) => b['photos'] as List)
          .where((p) => selected.containsKey(p['id']))
          .toList();
      expect(photos, hasLength(selected.length));
      for (final p in photos) {
        expect(File(p['asset']).existsSync(), true);
        final d = p['dimensions'];
        final size = Size(
          (d['width'] as num).toDouble(),
          (d['height'] as num).toDouble(),
        );
        final b = (p['subject'] as List)
            .map((v) => (v as num).toDouble())
            .toList();
        final subject = Rect.fromLTRB(b[0], b[1], b[2], b[3]);
        for (final viewport in [
          const Size(260, 140),
          const Size(340, 260),
          const Size(200, 300),
        ]) {
          final image = framedImageRect(viewport, size, subject);
          final visible = Rect.fromLTRB(
            image.left + b[0] * image.width,
            image.top + b[1] * image.height,
            image.left + b[2] * image.width,
            image.top + b[3] * image.height,
          );
          expect(visible.left, greaterThanOrEqualTo(0));
          expect(visible.top, greaterThanOrEqualTo(0));
          expect(visible.right, lessThanOrEqualTo(viewport.width));
          expect(visible.bottom, lessThanOrEqualTo(viewport.height));
        }
      }
    },
  );
}
