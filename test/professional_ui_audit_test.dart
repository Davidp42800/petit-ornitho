import 'package:petit_ornitho/ui/success_banner.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:petit_ornitho/data/game_store.dart';
import 'package:petit_ornitho/ui/app.dart';
import 'package:petit_ornitho/ui/home_screen.dart';
import 'package:petit_ornitho/ui/result_screen.dart';
import 'package:petit_ornitho/ui/quest_materials.dart';
import 'package:petit_ornitho/ui/quest_board.dart';
import 'package:petit_ornitho/ui/auth_screen.dart';
import 'package:petit_ornitho/ui/account_screen.dart';

class AuditStore extends GameStore {
  AuditStore(super.prefs, super.content, super.media);
  @override
  Future<void> syncQuestionWithdrawals() async {}
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      publishableKey: 'test',
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
      ),
    );
    final packages =
        jsonDecode(
              File('.dart_tool/package_config.json').readAsStringSync(),
            )['packages']
            as List;
    final flutter = packages.firstWhere((p) => p['name'] == 'flutter');
    final fonts = Uri.parse(
      '${flutter['rootUri']}/',
    ).resolve('../../bin/cache/artifacts/material_fonts/');
    final avenir = File('/System/Library/Fonts/Avenir.ttc');
    for (final entry in {
      'Avenir': avenir.existsSync() ? avenir.uri.toString() : 'Roboto-Regular.ttf',
      'Roboto': 'Roboto-Regular.ttf',
      'MaterialIcons': 'MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(entry.key)..addFont(
            Future.value(
              ByteData.sublistView(
                File.fromUri(fonts.resolve(entry.value)).readAsBytesSync(),
              ),
            ),
          ))
          .load();
    }
  });
  testWidgets(
    'Parcours, carnet, profil et bilan restent lisibles avec texte agrandi',
    (t) async {
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.view.resetPhysicalSize);
      for (final size in [
        const Size(320, 740),
        const Size(390, 844),
        const Size(1280, 900),
        const Size(844, 390),
      ]) {
        for (final scale in [1.0, 1.7]) {
          t.view.physicalSize = size;
          SharedPreferences.setMockInitialValues({});
          final prefs = await SharedPreferences.getInstance();
          final store = AuditStore(
            prefs,
            jsonDecode(File('assets/data/content.json').readAsStringSync()),
            jsonDecode(File('assets/data/media.json').readAsStringSync()),
          );
          store.reload();
          store.state['xp'] = 123456;
          await t.runAsync(() async {
            await store.start(1);
            await store.answer(store.current.answer);
          });
          final saved = jsonEncode(store.state);
          final boundary = GlobalKey();
          await t.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: OrnithoApp(store: store),
            ),
          );
          await t.pumpAndSettle();
          final app = t.widget<MaterialApp>(find.byType(MaterialApp));
          await t.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: MaterialApp(
                theme: app.theme,
                debugShowCheckedModeBanner: false,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(scale),
                    disableAnimations: scale > 1,
                  ),
                  child: child!,
                ),
                home: Home(store: store),
              ),
            ),
          );
          await t.pumpAndSettle();
          await t.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 250)),
          );
          Future<void> capture(String name) async {
            await t.pumpAndSettle();
            expect(
              t.takeException(),
              isNull,
              reason: '$name ${size.width} texte $scale',
            );
            await t.runAsync(() async {
              final image =
                  await (boundary.currentContext!.findRenderObject()
                          as RenderRepaintBoundary)
                      .toImage();
              final data = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final dir = Directory(
                'docs/screenshots/2026-10-25-professional-audit',
              );
              await dir.create(recursive: true);
              await File(
                '${dir.path}/$name-${size.width.toInt()}-$scale.png',
              ).writeAsBytes(data!.buffer.asUint8List());
              image.dispose();
            });
          }

          await capture('parcours');
          final objectives = find.text('Les objectifs de ta balade');
          await t.scrollUntilVisible(objectives, 180);
          await t.pumpAndSettle();
          await Scrollable.ensureVisible(t.element(objectives), alignment: .2);
          await t.pumpAndSettle();
          await t.tap(objectives.hitTestable());
          await capture('parcours-objectifs');
          for (final tab in ['Mon carnet', 'Pépi & moi']) {
            await t.tap(find.text(tab));
            await capture(tab == 'Mon carnet' ? 'carnet' : 'profil');
          }
          await t.scrollUntilVisible(find.text('Continuer mon parcours'), 200);
          await capture('profil-statistiques');
          await Scrollable.ensureVisible(
            t.element(find.text('Continuer mon parcours')),
            alignment: .3,
          );
          await t.pumpAndSettle();
          await t.tap(find.text('Continuer mon parcours').hitTestable());
          await t.pumpAndSettle();
          expect(find.byType(GameScreen), findsOneWidget);
          await t.pump(const Duration(seconds: 30));
          expect(jsonEncode(store.state), saved);
          final gameContext = t.element(find.byType(GameScreen));
          Navigator.of(gameContext).pop();
          await t.pumpAndSettle();
          expect(
            jsonEncode(store.state),
            saved,
            reason: 'La navigation doit préserver la session et son retour',
          );
          await t.pumpWidget(
            RepaintBoundary(
              key: boundary,
              child: MaterialApp(
                theme: app.theme,
                debugShowCheckedModeBanner: false,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(scale),
                    disableAnimations: scale > 1,
                  ),
                  child: child!,
                ),
                home: const ResultScreen(
                  result: {'correct': 5, 'total': 6, 'score': 12345},
                ),
              ),
            ),
          );
          await capture('bilan');
          await t.scrollUntilVisible(
            find.text('Retrouver mon parcours →'),
            200,
          );
          await capture('bilan-statistiques');
          Future<void> page(Widget child, String name) async {
            await t.pumpWidget(
              RepaintBoundary(
                key: boundary,
                child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: app.theme,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(scale),
                      disableAnimations: scale > 1,
                    ),
                    child: child!,
                  ),
                  home: child,
                ),
              ),
            );
            await t.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 100)),
            );
            await capture(name);
          }

          await page(AuthScreen(store: store), 'connexion');
          await page(AccountScreen(store: store), 'compte');
          final question = store.questions.firstWhere((q) => q.kind == 'photo');
          for (final state in ['entree', 'erreur', 'reussite']) {
            final correct = state == 'reussite';
            final choice = correct
                ? question.answer
                : (question.answer + 1) % question.options.length;
            await page(
              QuestBoard(
                question: question,
                species: store.species,
                journeyName: 'Forêts et prairies',
                selected: state == 'entree' ? null : choice,
                feedback: state == 'entree'
                    ? null
                    : {
                        'correct': correct,
                        'answer': question.answer,
                        'choice': choice,
                        'points': correct ? 15 : 0,
                      },
                busy: false,
                error: null,
                step: 2,
                total: 6,
                score: 15,
                onSelect: (_) {},
                onConfirm: () {},
                onNext: () {},
                onPause: () {},
                onSource: () {},
              ),
              'mission-$state',
            );
          }
          await t.pumpWidget(const SizedBox());
        }
      }
    },
  );
  testWidgets(
    'Un bouton de jeu désactivé expose son état aux aides techniques',
    (t) async {
      final semantics = t.ensureSemantics();

      await t.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: QuestButton(child: Text('Valider'))),
        ),
      );
      expect(
        t.getSemantics(find.byType(QuestButton)),
        matchesSemantics(
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
          label: 'Valider',
        ),
      );
      semantics.dispose();
    },
  );
  testWidgets(
    'Une seule action suivante après réussite et aucune avance automatique',
    (t) async {
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.view.resetPhysicalSize);
      for (final width in [390.0, 837.0]) {
        t.view.physicalSize = Size(width, 907);
        SharedPreferences.setMockInitialValues({});
        final store = AuditStore(
          await SharedPreferences.getInstance(),
          jsonDecode(File('assets/data/content.json').readAsStringSync()),
          jsonDecode(File('assets/data/media.json').readAsStringSync()),
        );
        store.reload();
        await store.start(1);
        final photo = store.questions.firstWhere((q) => q.kind == 'photo');
        final following = store.questions.firstWhere((q) => q.id != photo.id);
        (store.state['active'] as Map)['ids'] = [photo.id, following.id];
        final boundary = GlobalKey();
        await t.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              home: GameScreen(store: store),
            ),
          ),
        );
        await t.pumpAndSettle();
        final answer = find.text(photo.options[photo.answer]);
        await t.scrollUntilVisible(answer, 160);
        await t.pumpAndSettle();
        await Scrollable.ensureVisible(t.element(answer), alignment: .4);
        await t.pumpAndSettle();
        await t.tap(answer.hitTestable());
        await t.pump();
        await t.pump(const Duration(milliseconds: 900));
        expect(
          find.byType(SuccessBanner),
          findsOneWidget,
          reason: 'Une seule célébration doit être visible',
        );
        await t.pumpAndSettle();
        expect(store.active!['feedback']['correct'], isTrue);
        expect(
          find.text('Suivant'),
          findsNothing,
          reason:
              'La couche de célébration ne doit pas recouvrir la commande du plateau',
        );
        expect(
          find.byWidgetPredicate((w) => w is FilledButton),
          findsOneWidget,
        );
        final score = store.active!['score'];
        await t.pump(const Duration(seconds: 30));
        expect(store.active!['index'], 0);
        expect(store.active!['score'], score);
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 250)),
        );
        await t.pumpAndSettle();
        await t.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final dir = Directory('docs/screenshots/2026-10-25-single-next');
          await dir.create(recursive: true);
          await File(
            '${dir.path}/success-${width.toInt()}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
        await t.tap(find.text('Continuer →').hitTestable());
        await t.pumpAndSettle();
        expect(
          store.active!['index'],
          1,
          reason: 'Un clic avance d’un seul défi',
        );
        expect(store.active!['score'], score);
        await t.pumpWidget(const SizedBox());
        expect(t.takeException(), isNull);
      }
    },
  );
}
