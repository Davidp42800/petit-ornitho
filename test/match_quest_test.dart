import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petit_ornitho/domain/game.dart';
import 'package:petit_ornitho/ui/quest_board.dart';

void main() {
  testWidgets('Association : choisir, changer, valider, erreur et réussite', (
    t,
  ) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    for (final entry in {
      'Avenir': '/System/Library/Fonts/Avenir Next.ttc',
      'MaterialIcons':
          '/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    }.entries) {
      final f = File(entry.value);
      if (f.existsSync()) {
        await (FontLoader(
              entry.key,
            )..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync()))))
            .load();
      }
    }
    final content = jsonDecode(
      File('assets/data/content.json').readAsStringSync(),
    );
    final q = Question(
      Map<String, dynamic>.from(
        (content['questions'] as List).firstWhere(
          (q) => q['id'] == 'robin_match',
        ),
      ),
    );
    int? selected;
    dynamic feedback;
    var answers = 0;
    var continued = false;
    late StateSetter update;
    final key = GlobalKey();
    await t.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(fontFamily: 'Avenir'),
          home: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return QuestBoard(
                question: q,
                species: content['species'],
                selected: selected,
                feedback: feedback,
                busy: false,
                error: null,
                step: 3,
                total: 6,
                score: 30,
                onPause: () {},
                onSource: () {},
                onSelect: (v) => setState(() => selected = v),
                onConfirm: () => setState(() {
                  answers++;
                  feedback = {
                    'choice': selected,
                    'answer': q.answer,
                    'correct': selected == q.answer,
                    'points': selected == q.answer ? 15 : 0,
                  };
                }),
                onNext: () => continued = true,
              );
            },
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.runAsync(() async {
      for (final bird in content['species']) {
        await precacheImage(
          AssetImage('assets/birds/${bird['id']}.jpg'),
          key.currentContext!,
        );
      }
    });
    await t.pumpAndSettle();
    await t.runAsync(
      () => precacheImage(
        const AssetImage('assets/art/swiss-garden-v1.png'),
        key.currentContext!,
      ),
    );
    await t.pumpAndSettle();
    Future<void> capture(String name) async {
      if (!Platform.isMacOS) return;
      await t.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          'docs/screenshots/$name.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    expect(t.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    expect(find.text('Rougegorge familier'), findsOneWidget);
    await capture('match-start');
    await t.tap(find.text('Rougegorge familier'));
    await t.pumpAndSettle();
    expect(selected, 0);
    expect(answers, 0);
    await capture('match-selected');
    await t.tap(find.text('Merle noir'));
    await t.pumpAndSettle();
    expect(selected, 1);
    await t.tap(find.text('Valider mon choix'));
    await t.pumpAndSettle();
    expect(answers, 1);
    expect(find.text('Bonne réponse'), findsOneWidget);
    expect(find.text('Ton choix'), findsOneWidget);
    await capture('match-error');
    await t.tap(find.text('Rougegorge familier'));
    expect(answers, 1);
    expect(selected, 1);
    await t.tap(find.text('Continuer →'));
    expect(continued, isTrue);
    update(() {
      selected = null;
      feedback = null;
    });
    await t.pumpAndSettle();
    final gesture = await t.startGesture(
      t.getCenter(find.text('Rougegorge familier')),
    );
    await t.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(t.getCenter(find.byType(DragTarget<int>)));
    await t.pump(const Duration(milliseconds: 200));
    await gesture.up();
    await t.pumpAndSettle();
    expect(selected, 0);
    await t.tap(find.text('Valider mon choix'));
    await t.pumpAndSettle();
    expect(find.text('Bien observé ! +15 plumes'), findsOneWidget);
    await capture('match-success');
    expect(t.takeException(), isNull);
    // Enlarged text uses a single column and preserves the confirmation action.
    await t.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: QuestBoard(
            question: q,
            species: content['species'],
            selected: null,
            feedback: null,
            busy: false,
            error: null,
            step: 1,
            total: 6,
            score: 0,
            onSelect: (_) {},
            onConfirm: () {},
            onNext: () {},
            onPause: () {},
            onSource: () {},
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
  testWidgets('Photo : rendu mobile, réponse unique et retour explicite', (
    t,
  ) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final content = jsonDecode(
      File('assets/data/content.json').readAsStringSync(),
    );
    final q = Question(
      Map<String, dynamic>.from(
        (content['questions'] as List).firstWhere(
          (q) => q['id'] == 'robin_photo',
        ),
      ),
    );
    dynamic feedback;
    var calls = 0;
    var continued = false;
    late StateSetter update;
    final key = GlobalKey();
    await t.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(fontFamily: 'Avenir'),
          home: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return QuestBoard(
                question: q,
                species: content['species'],
                selected: null,
                feedback: feedback,
                busy: false,
                error: null,
                step: 1,
                total: 6,
                score: 0,
                onPause: () {},
                onSource: () {},
                onConfirm: () {},
                onSelect: (v) => setState(() {
                  calls++;
                  feedback = {
                    'choice': v,
                    'answer': q.answer,
                    'correct': v == q.answer,
                    'points': v == q.answer ? 15 : 0,
                  };
                }),
                onNext: () => continued = true,
              );
            },
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.runAsync(
      () => precacheImage(
        AssetImage('assets/birds/${q.species}.jpg'),
        key.currentContext!,
      ),
    );
    await t.pumpAndSettle();
    await t.runAsync(
      () => precacheImage(
        const AssetImage('assets/art/swiss-garden-v1.png'),
        key.currentContext!,
      ),
    );
    await t.pumpAndSettle();
    Future<void> capture(String name) async {
      if (!Platform.isMacOS) return;
      await t.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          'docs/screenshots/$name.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await capture('photo-start');
    await t.tap(find.text('Merle noir'));
    await t.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('À retenir'), findsOneWidget);
    await capture('photo-error');
    await t.ensureVisible(find.text('Rougegorge familier'));
    await t.pumpAndSettle();
    await t.tap(find.text('Rougegorge familier'));
    expect(calls, 1);
    await t.tap(find.text('Continuer →'));
    expect(continued, isTrue);
    update(() => feedback = null);
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Rougegorge familier'));
    await t.pumpAndSettle();
    await t.tap(find.text('Rougegorge familier'));
    await t.pumpAndSettle();
    expect(find.text('Bien observé ! +15 plumes'), findsOneWidget);
    await t.scrollUntilVisible(find.text('Quel oiseau observes-tu ?'), -300);
    await t.pumpAndSettle();
    await capture('photo-success');
    expect(t.takeException(), isNull);
  });
}
