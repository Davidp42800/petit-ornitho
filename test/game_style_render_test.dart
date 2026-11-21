import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petit_ornitho/domain/game.dart';
import 'package:petit_ornitho/domain/bird_recording.dart';
import 'package:petit_ornitho/ui/audio_mission.dart';
import 'package:petit_ornitho/ui/listening_screen.dart';
import 'package:petit_ornitho/ui/picture_choice_board.dart';
import 'package:petit_ornitho/ui/quest_board.dart';
import 'package:petit_ornitho/ui/bird_photo.dart';
import 'package:petit_ornitho/ui/retry_feedback.dart';

class SilentAudio implements BirdAudio {
  @override
  Future<void> play(BirdRecording r) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

void main() {
  testWidgets('Shared garden style on narrow and wide game boards', (t) async {
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    for (final e in {
      'Avenir': '/System/Library/Fonts/Avenir Next.ttc',
      'MaterialIcons':
          '/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(e.key)..addFont(
            Future.value(ByteData.sublistView(File(e.value).readAsBytesSync())),
          ))
          .load();
    }
    dynamic read(String f) => jsonDecode(File(f).readAsStringSync());
    final content = read('assets/data/content.json');
    final q = Question(
      Map<String, dynamic>.from(
        content['questions'].firstWhere((q) => q['id'] == 'robin_photo'),
      ),
    );
    final picture = Question(
      Map<String, dynamic>.from(
        read('data/editorial/picture-missions/questions.json').first,
      ),
    );
    final sound = Question(
      Map<String, dynamic>.from(
        read('data/editorial/audio-release/missions.json').first,
      ),
    );
    final clip = BirdRecording.validated([
      sound.data['recording'],
    ], read('assets/data/species_catalog.json')['species']).single;
    for (final size in [const Size(390, 844), const Size(734, 977)]) {
      t.view.physicalSize = size;
      for (final page in ['photo', 'picture', 'audio']) {
        final key = GlobalKey();
        final widget = page == 'photo'
            ? QuestBoard(
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
              )
            : page == 'picture'
            ? PictureChoiceBoard(
                question: picture,
                feedback: null,
                busy: false,
                step: 1,
                total: 6,
                onAnswer: (_) {},
                onNext: () {},
              )
            : AudioMission(
                question: sound,
                recording: clip,
                feedback: null,
                busy: false,
                step: 1,
                total: 6,
                onAnswer: (_) {},
                onNext: () {},
                onPause: () {},
                beforeHint: () async => true,
                audioFactory: () => SilentAudio(),
              );
        await t.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                fontFamily: 'Avenir',
                colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xff087a83),
                  surface: const Color(0xfff4fbff),
                ),
                appBarTheme: const AppBarTheme(
                  backgroundColor: Color(0xff145b72),
                  foregroundColor: Color(0xfffff9e5),
                  centerTitle: true,
                ),
              ),
              home: RetryFeedback(
                wrong: page == 'photo' ? {1} : const {},
                child: widget,
              ),
            ),
          ),
        );
        await t.runAsync(() async {
          final assets = <String>{
            'assets/art/swiss-garden-v1.png',
            'assets/art/pio-evolution-v1.png',
            'assets/birds/${q.species}.jpg',
            for (final p in picture.data['image_options'])
              bundledBirdAsset(p['asset']),
            for (final p in sound.data['option_photos'])
              bundledBirdAsset(p['photo']['asset']),
          };
          for (final path in assets) {
            await precacheImage(AssetImage(path), key.currentContext!);
          }
        });
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        await t.runAsync(() async {
          final im =
              await (key.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final data = await im.toByteData(format: ui.ImageByteFormat.png);
          File(
            'docs/screenshots/style-$page-${size.width.toInt()}.png',
          ).writeAsBytesSync(data!.buffer.asUint8List());
          im.dispose();
        });
        await t.pumpWidget(const SizedBox());
        await t.pumpAndSettle();
      }
    }
  });
}
