import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:petit_ornitho/data/game_store.dart';
import 'package:petit_ornitho/ui/hidden_bird_screen.dart';
import 'package:petit_ornitho/ui/letter_delivery.dart';
import 'package:petit_ornitho/ui/game_effects.dart';

void main() {
  testWidgets(
    'Letter arrives once; flight can be closed; reduced motion reveals immediately',
    (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final data = jsonDecode(
        File('assets/data/content.json').readAsStringSync(),
      );
      final store = GameStore(await SharedPreferences.getInstance(), data, []);
      final boundary = GlobalKey();
      for (final item in {
        'Roboto': 'Roboto-Regular.ttf',
        'MaterialIcons': 'MaterialIcons-Regular.otf',
      }.entries) {
        final file = File(
          '/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts/${item.value}',
        );
        await (FontLoader(item.key)..addFont(
              Future.value(ByteData.sublistView(file.readAsBytesSync())),
            ))
            .load();
      }
      await t.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: HiddenBirdScreen(store: store),
          ),
        ),
      );
      await t.runAsync(
        () => precacheImage(
          const AssetImage('assets/art/pio-evolution-v1.png'),
          boundary.currentContext!,
        ),
      );
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Découvrir une lettre'));
      await t.pumpAndSettle();
      await t.tap(find.text('Découvrir une lettre'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 230));
      await t.pump();
      expect(find.byType(LetterDelivery), findsOneWidget);
      await t.pump(const Duration(milliseconds: 540));
      expect(find.textContaining('ont apporté'), findsNothing);
      await t.runAsync(() async {
        final image =
            await (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File(
          'docs/screenshots/letter-delivery.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await t.pumpAndSettle();
      expect(find.byType(LetterDelivery), findsNothing);
      expect(find.textContaining('ont apporté la lettre'), findsOneWidget);
      await t.ensureVisible(find.text('Découvrir une lettre'));
      await t.pumpAndSettle();
      await t.tap(find.text('Découvrir une lettre'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 230));
      await t.pumpWidget(const MaterialApp(home: SizedBox()));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await t.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: HiddenBirdScreen(store: store),
        ),
      );
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Découvrir une lettre'));
      await t.tap(find.text('Découvrir une lettre'));
      await t.pump();
      expect(find.byType(LetterDelivery), findsNothing);
      expect(find.textContaining('ont apporté la lettre'), findsOneWidget);
    },
  );
  testWidgets(
    'Game celebration does not block taps and has no perpetual ticker',
    (t) async {
      var taps = 0;
      Widget app(Object? event) => MaterialApp(
        home: Scaffold(
          body: GameEffects(
            event: event,
            success: true,
            child: Center(
              child: TextButton(
                onPressed: () => taps++,
                child: const Text('Continuer'),
              ),
            ),
          ),
        ),
      );
      await t.pumpWidget(app(null));
      await t.pumpAndSettle();
      await t.pumpWidget(app('answer-1'));
      await t.pump(const Duration(milliseconds: 250));
      await t.tap(find.text('Continuer'));
      expect(taps, 1);
      await t.pumpAndSettle();
      expect(t.hasRunningAnimations, isFalse);
      expect(t.takeException(), isNull);
    },
  );
}
