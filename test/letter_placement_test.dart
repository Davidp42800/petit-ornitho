import 'test_paths.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petit_ornitho/domain/game.dart';
import 'package:petit_ornitho/ui/hidden_name_input.dart';
import 'package:petit_ornitho/ui/mystery_photo_hint.dart';

void main() {
  testWidgets(
    'Letters advance automatically across words; replace and submit',
    (t) async {
      t.view.physicalSize = const Size(734, 1100);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await (FontLoader('Avenir')..addFont(
            Future.value(
              ByteData.sublistView(
                File(testAvenirPath()).readAsBytesSync(),
              ),
            ),
          ))
          .load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      int? answer;
      final boundary = GlobalKey();
      await t.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'Avenir'),
          home: Scaffold(
            body: RepaintBoundary(
              key: boundary,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: HiddenNameInput(
                    question: Question({
                      'id': 'letters',
                      'kind': 'mystery',
                      'species_id': 'test',
                      'options': ['Merle noir', 'Sittelle torchepot'],
                      'answer': 0,
                    }),
                    photoHint: MysteryPhotoHint(
                      species: 'robin',
                      photo: {'asset': 'assets/birds/robin.jpg'},
                      busy: false,
                      beforeHint: () async => true,
                      onSource: () {},
                    ),
                    locked: false,
                    beforeHint: () async => true,
                    onAnswer: (i) => answer = i,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await t.runAsync(() async {
        await precacheImage(
          const AssetImage('assets/art/pio-evolution-v1.png'),
          boundary.currentContext!,
        );
      });
      await t.pump();
      // A wrong tap must leave the keyboard ready for the same slot.
      final wrong = find.byWidgetPredicate(
        (w) =>
            w is OutlinedButton &&
            w.key.toString().contains('bank-letter') &&
            w.onPressed != null &&
            w.child is Text &&
            (w.child as Text).data == 'E',
      );
      await t.tap(wrong.first);
      await t.pump();
      expect(
        find.text('Pas cette lettre ! Essaie une autre touche.'),
        findsOneWidget,
      );
      expect(wrong, findsWidgets);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('letter-slot-0')),
          matching: find.text('E'),
        ),
        findsOneWidget,
      );
      expect(
        t
            .widget<OutlinedButton>(find.byKey(const ValueKey('letter-slot-0')))
            .style!
            .backgroundColor!
            .resolve({}),
        const Color(0xffffd9d5),
      );
      // Tapping the rejected letter clears it and keeps this slot ready.
      await t.tap(find.byKey(const ValueKey('letter-slot-0')));
      await t.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('letter-slot-0')),
          matching: find.text('—'),
        ),
        findsOneWidget,
      );
      expect(find.text('À toi : lettre 1'), findsOneWidget);
      expect(
        find.text('Pas cette lettre ! Essaie une autre touche.'),
        findsNothing,
      );
      expect(answer, isNull);
      expect(wrong, findsWidgets);
      await t.tap(wrong.first);
      await t.pumpAndSettle();
      // Moving to another slot also clears the rejected preview and message.
      await t.tap(find.byKey(const ValueKey('letter-slot-3')));
      await t.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('letter-slot-0')),
          matching: find.text('—'),
        ),
        findsOneWidget,
      );
      expect(
        find.text('Pas cette lettre ! Essaie une autre touche.'),
        findsNothing,
      );
      expect(wrong, findsWidgets);
      await t.tap(find.byKey(const ValueKey('letter-slot-0')));
      await t.pump();
      const name = 'MERLE NOIR';
      for (var i = 0; i < name.length; i++) {
        if (name[i] == ' ') continue;
        final candidates = find.byWidgetPredicate(
          (w) =>
              w is OutlinedButton &&
              w.key.toString().contains('bank-letter') &&
              w.onPressed != null &&
              w.child is Text &&
              (w.child as Text).data == name[i],
        );
        expect(candidates, findsWidgets);
        await t.ensureVisible(candidates.first);
        await t.tap(candidates.first);
        await t.pump();
      }
      await t.tap(find.byKey(const ValueKey('letter-slot-0')));
      await t.pump();
      await t.ensureVisible(find.text('Retirer cette lettre'));
      await t.tap(find.text('Retirer cette lettre'));
      await t.pump();
      final m = find.byWidgetPredicate(
        (w) =>
            w is OutlinedButton &&
            w.key.toString().contains('bank-letter') &&
            w.onPressed != null &&
            w.child is Text &&
            (w.child as Text).data == 'M',
      );
      await t.tap(m);
      await t.pump();
      expect(find.text('Je propose ce nom'), findsNothing);
      await t.pump();
      expect(answer, 0);
      expect(t.takeException(), isNull);
      await t.runAsync(() async {
        final img =
            await (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '${Directory.systemTemp.path}/joli-bec-letter-board.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
      });
    },
  );
  testWidgets('Accepted letters preserve accents from the bird name', (
    t,
  ) async {
    t.view.physicalSize = const Size(734, 1100);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: HiddenNameInput(
              question: Question({
                'id': 'accent',
                'kind': 'mystery',
                'species_id': 'test',
                'options': ['Mésange à longue queue'],
                'answer': 0,
              }),
              locked: false,
              beforeHint: () async => true,
              onAnswer: (_) {},
            ),
          ),
        ),
      ),
    );
    // Unaccented tokens are accepted, but the answer always uses correct spelling.
    for (final entry in {1: 'E', 8: 'A'}.entries) {
      await t.tap(find.byKey(ValueKey('letter-slot-${entry.key}')));
      await t.pump();
      final token = find.byWidgetPredicate(
        (w) =>
            w is OutlinedButton &&
            w.key.toString().contains('bank-letter') &&
            w.onPressed != null &&
            w.child is Text &&
            (w.child as Text).data == entry.value,
      );
      await t.ensureVisible(token.first);
      await t.tap(token.first);
      await t.pump();
      expect(
        find.descendant(
          of: find.byKey(ValueKey('letter-slot-${entry.key}')),
          matching: find.text(entry.key == 1 ? 'É' : 'À'),
        ),
        findsOneWidget,
      );
    }
    expect(t.takeException(), isNull);
  });
}
