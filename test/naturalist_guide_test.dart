import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petit_ornitho/domain/game.dart';
import 'package:petit_ornitho/ui/naturalist_guide.dart';

void main() {
  final data = jsonDecode(File('assets/data/content.json').readAsStringSync());
  final q = Question(Map<String, dynamic>.from(data['questions'][0]));
  testWidgets(
    'Pépi waits for assistance acknowledgement before revealing help',
    (t) async {
      final ack = Completer<bool>();
      var calls = 0;
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NaturalistGuideButton(
              question: q,
              answered: false,
              beforeHint: () => ack.future,
              loader: (_, _) async {
                calls++;
                return {};
              },
            ),
          ),
        ),
      );
      await t.tap(find.text('Aide de Pépi'));
      await t.pump();
      expect(calls, 0);
      expect(find.byTooltip('Fermer le guide'), findsNothing);
      ack.complete(false);
      await t.pumpAndSettle();
      expect(calls, 0);
      expect(find.byTooltip('Fermer le guide'), findsNothing);
    },
  );
  testWidgets(
    'Guide: immediate local help, async explanation, large mobile text',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final item in {
        'Roboto': 'Roboto-Regular.ttf',
        'MaterialIcons': 'MaterialIcons-Regular.otf',
      }.entries) {
        final file = File(
          '/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts/${item.value}',
        );
        if (file.existsSync()) {
          await (FontLoader(item.key)..addFont(
                Future.value(ByteData.sublistView(file.readAsBytesSync())),
              ))
              .load();
        }
      }
      final response = Completer<Map<String, dynamic>>();
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(1.5)),
              child: child!,
            ),
            home: Scaffold(
              body: Center(
                child: NaturalistGuideButton(
                  question: q,
                  answered: true,
                  loader: (id, mode) {
                    expect(id, q.id);
                    expect(mode, 'explain');
                    return response.future;
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(
        () => precacheImage(
          const AssetImage('assets/art/pio-evolution-v1.png'),
          boundary.currentContext!,
        ),
      );
      await tester.tap(find.text('Explique-moi'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text(q.explanation), findsOneWidget);
      response.complete({
        'message': 'Observe les couleurs décrites dans la fiche.',
        'origin': 'ai',
      });
      await tester.pumpAndSettle();
      expect(
        find.text('Observe les couleurs décrites dans la fiche.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File(
          'docs/screenshots/guide-mobile.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await tester.tap(find.byTooltip('Fermer le guide'));
      await tester.pumpAndSettle();
    },
  );
  testWidgets('Guide offline fallback and closing during request are safe', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NaturalistGuideButton(
            question: q,
            answered: false,
            loader: (_, _) async => throw StateError('offline'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Aide de Pépi'));
    await tester.pumpAndSettle();
    expect(find.text(guideHint(q)), findsOneWidget);
    expect(
      find.textContaining('disponible aussi hors connexion'),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Fermer le guide'));
    await tester.pumpAndSettle();
    final response = Completer<Map<String, dynamic>>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NaturalistGuideButton(
            question: q,
            answered: false,
            loader: (_, _) => response.future,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Aide de Pépi'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byTooltip('Fermer le guide'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    response.complete({'message': 'Trop tard', 'origin': 'ai'});
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Trop tard'), findsNothing);
  });
}
