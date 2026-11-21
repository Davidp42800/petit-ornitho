import 'test_paths.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petit_ornitho/ui/field_choice.dart';

void main() {
  testWidgets('One tap submits once, busy locks and failure allows retry', (t) async {
    final answers = <int>[];
    Widget screen(bool locked) => MaterialApp(home: Scaffold(body: FieldChoice(
      options: const ['Une cavité', 'Une branche'], locked: locked, onAnswer: answers.add)));
    await t.pumpWidget(screen(false));
    expect(find.text('Je valide mon choix'), findsNothing);
    expect(find.byType(Draggable<String>), findsNothing);
    final choice = find.byKey(const ValueKey('field-option-0'));
    await t.tap(choice);
    await t.tap(choice);
    expect(answers, [0]);
    await t.pumpWidget(screen(true));
    await t.tap(choice);
    expect(answers, [0]);
    await t.pumpWidget(screen(false));
    await t.tap(choice);
    expect(answers, [0, 0]);
  });
  testWidgets('Readable on small mobile with long options and large text', (
    t,
  ) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final font = File(testAvenirPath());
    if (font.existsSync()) {
      await (FontLoader('Avenir')..addFont(
            Future.value(ByteData.sublistView(font.readAsBytesSync())),
          ))
          .load();
    }
    final icons = File(
      testFontPath('MaterialIcons-Regular.otf'),
    );
    if (icons.existsSync()) {
      await (FontLoader('MaterialIcons')..addFont(
            Future.value(ByteData.sublistView(icons.readAsBytesSync())),
          ))
          .load();
    }
    final key = GlobalKey();
    await t.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          theme: ThemeData(fontFamily: 'Avenir'),
          debugShowCheckedModeBanner: false,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.25)),
            child: Scaffold(
              backgroundColor: const Color(0xfffaf7ed),
              appBar: AppBar(title: const Text('Où est mon nid ?')),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: FieldChoice(
                  options: const [
                    'Dans un tunnel creusé dans une berge',
                    'Dans un nid flottant sur l’étang',
                    'Sur une branche, à découvert',
                  ],
                  locked: false,
                  onAnswer: (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.byKey(const ValueKey('field-option-0')));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    if (Platform.isMacOS) {
      await t.runAsync(() async {
        final img =
            await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        File(
          'docs/screenshots/field-choice-mobile.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
        img.dispose();
      });
    }
  });
}
