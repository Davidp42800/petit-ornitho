import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petit_ornitho/domain/game.dart';
import 'package:petit_ornitho/domain/bird_recording.dart';
import 'package:petit_ornitho/ui/audio_mission.dart';
import 'package:petit_ornitho/ui/listening_screen.dart';

class TestAudio implements BirdAudio {
  bool fail = false, disposed = false;
  int plays = 0, stops = 0;
  Completer<void>? pending;
  @override
  Future<void> play(BirdRecording clip) async {
    plays++;
    await pending?.future;
    if (fail) throw StateError('offline');
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

void main() {
  testWidgets('Annuler puis relancer protège la seconde écoute', (t) async {
    t.view.physicalSize = const Size(734, 977);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final q = Question(
      Map<String, dynamic>.from(
        (jsonDecode(
                  File(
                    'data/editorial/audio-release/missions.json',
                  ).readAsStringSync(),
                )
                as List)
            .first,
      ),
    );
    final species =
        jsonDecode(
              File('assets/data/species_catalog.json').readAsStringSync(),
            )['species']
            as List;
    final clip = BirdRecording.validated([q.data['recording']], species).single;
    final first = TestAudio()..pending = Completer<void>();
    final second = TestAudio();
    final players = [first, second];
    await t.pumpWidget(
      MaterialApp(
        home: AudioMission(
          question: q,
          recording: clip,
          feedback: null,
          busy: false,
          step: 1,
          total: 6,
          onAnswer: (_) {},
          onNext: () {},
          onPause: () {},
          beforeHint: () async => true,
          audioFactory: () => players.removeAt(0),
        ),
      ),
    );
    await t.tap(find.byTooltip('Écouter l’oiseau'));
    await t.pump();
    await t.tap(find.byTooltip('Annuler le chargement'));
    await t.pump();
    await t.tap(find.byTooltip('Écouter l’oiseau'));
    await t.pump();
    first.pending!.complete();
    await t.pump(const Duration(seconds: 2));
    expect(first.disposed, isTrue);
    expect(second.plays, 1);
    expect(second.stops, 0);
    expect(second.disposed, isFalse);
    expect(find.byTooltip('Arrêter le son'), findsOneWidget);
    await t.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('Success stays readable until explicit Next', (t) async {
    t.view.physicalSize = const Size(734, 977);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await (FontLoader('Roboto')..addFont(
          Future.value(
            ByteData.sublistView(
              File(
                '/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
              ).readAsBytesSync(),
            ),
          ),
        ))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    final q = Question(
      Map<String, dynamic>.from(
        (jsonDecode(
                  File(
                    'data/editorial/audio-release/missions.json',
                  ).readAsStringSync(),
                )
                as List)
            .first,
      ),
    );
    final species =
        jsonDecode(
              File('assets/data/species_catalog.json').readAsStringSync(),
            )['species']
            as List;
    final clip = BirdRecording.validated([q.data['recording']], species).single;
    for (final width in [734.0, 390.0]) {
      t.view.physicalSize = Size(width, 977);
      var advances = 0;
      final boundary = GlobalKey();
      await t.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(
            key: boundary,
            child: AudioMission(
              key: ValueKey(width),
              question: q,
              recording: clip,
              feedback: {'correct': true, 'answer': q.data['answer']},
              busy: false,
              step: 1,
              total: 6,
              onAnswer: (_) {},
              onNext: () => advances++,
              onPause: () {},
              beforeHint: () async => true,
              audioFactory: TestAudio.new,
            ),
          ),
        ),
      );
      await t.pump();
      await t.pump(const Duration(milliseconds: 800));
      await t.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File(
          '/private/tmp/ornitho-victory-${width.toInt()}.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await t.pump(const Duration(seconds: 3));
      expect(advances, 0);
      await t.pump(const Duration(seconds: 30));
      expect(advances, 0);
      expect(find.text('Rester lire'), findsNothing);
      await t.tap(find.text('Suivant'));
      await t.pump();
      expect(advances, 1);
      await t.pumpWidget(const SizedBox.shrink());
    }
  });
  testWidgets(
    'Audio mission requires a heard sample; errors retry without answering',
    (t) async {
      t.view.physicalSize = const Size(734, 977);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await (FontLoader('Avenir')..addFont(
            Future.value(
              ByteData.sublistView(
                File('/System/Library/Fonts/Avenir Next.ttc').readAsBytesSync(),
              ),
            ),
          ))
          .load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      final boundary = GlobalKey();
      final q = Question(
        Map<String, dynamic>.from(
          (jsonDecode(
                    File(
                      'data/editorial/audio-release/missions.json',
                    ).readAsStringSync(),
                  )
                  as List)
              .first,
        ),
      );
      final species =
          jsonDecode(
                File('assets/data/species_catalog.json').readAsStringSync(),
              )['species']
              as List;
      final clip = BirdRecording.validated([
        q.data['recording'],
      ], species).single;
      final audio = TestAudio()..fail = true;
      final choices = <int>[];
      var moderationCalls = 0;
      await t.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            theme: ThemeData(fontFamily: 'Avenir'),
            home: AudioMission(
              level: 4,
              question: q,
              recording: clip,
              feedback: null,
              busy: false,
              step: 1,
              total: 6,
              onAnswer: choices.add,
              onNext: () {},
              onPause: () {},
              onModerate: () => moderationCalls++,
              beforeHint: () async => true,
              audioFactory: () => audio,
            ),
          ),
        ),
      );
      expect(find.text('Un autre'), findsOneWidget);
      await t.tap(find.byTooltip('Écarter cette question'));
      await t.pump();
      expect(moderationCalls, 1);
      expect(choices, isEmpty);
      final answer = find.byType(OutlinedButton).first;
      expect(t.widget<OutlinedButton>(answer).onPressed, isNull);
      await t.tap(find.byTooltip('Écouter l’oiseau'));
      await t.pumpAndSettle();
      expect(find.textContaining('Le son ne se charge pas'), findsOneWidget);
      expect(choices, isEmpty);
      audio.fail = false;
      await t.tap(find.byTooltip('Écouter l’oiseau'));
      await t.pump();
      expect(t.widget<OutlinedButton>(answer).onPressed, isNull);
      await t.pump(const Duration(seconds: 2));
      expect(t.widget<OutlinedButton>(answer).onPressed, isNotNull);
      await t.tap(find.byTooltip('Arrêter le son'));
      await t.pump();
      await t.tap(find.byTooltip('Écouter l’oiseau'));
      await t.pump();
      expect(audio.plays, 3);
      expect(find.textContaining('Le son ne se charge pas'), findsNothing);
      await t.pump(const Duration(seconds: 2));
      await t.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '/private/tmp/audio-mission.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
      });
      await t.tap(answer);
      await t.pump();
      expect(choices, [0]);
      await t.pumpWidget(const SizedBox.shrink());
      expect(audio.disposed, true);
    },
  );
}
