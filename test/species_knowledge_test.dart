import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:petit_ornitho/data/game_store.dart';
import 'package:petit_ornitho/ui/species_knowledge.dart';

void main() {
  final snapshot = jsonDecode(
    File('assets/data/published_species_facts.json').readAsStringSync(),
  );
  test(
    'Every displayed fact belongs to an allowed taxon and has document provenance',
    () {
      final species = jsonDecode(
        File('assets/data/species_catalog.json').readAsStringSync(),
      );
      final ids = (species['species'] as List).map((b) => b['id']).toSet();
      final seen = <String>{};
      for (final fact in snapshot['facts']) {
        expect(ids, contains(fact['species_id']));
        expect(seen.add(fact['id']), true);
        expect(fact['id'], isNot(endsWith('latin_fact')));
        expect(fact['statement'], isNotEmpty);
        expect(Uri.parse(fact['source_url']).scheme, 'https');
        expect(fact['sha256'], matches(RegExp(r'^[a-f0-9]{64}$')));
        expect(
          fact['page'] != null ||
              fact['section'] != null ||
              fact['source_locator'] != null,
          true,
        );
      }
    },
  );
  test(
    'An authoritative empty profile cannot inherit legacy descriptive facts',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = GameStore(
        await SharedPreferences.getInstance(),
        {
          'species': [
            {
              'id': 'x',
              'facts': ['Legacy unsupported statement'],
            },
          ],
          'questions': [],
        },
        [],
        publishedFacts: [],
      );
      expect(store.sourcedFactsFor('x'), isEmpty);
    },
  );
  test(
    'Archived notebook supplements fill absent topics without changing missions',
    () async {
      final supplements = snapshot['card_supplements'] as List;
      expect(supplements, isNotEmpty);
      SharedPreferences.setMockInitialValues({});
      final store = GameStore(
        await SharedPreferences.getInstance(),
        {'species': [], 'questions': []},
        [],
        publishedFacts: snapshot['facts'],
        cardSupplements: supplements,
      );
      final published = {
        for (final fact in snapshot['facts'])
          (fact['species_id'], fact['topic']),
      };
      for (final supplement in supplements) {
        expect(
          published.add((supplement['species_id'], supplement['topic'])),
          isTrue,
        );
        expect(supplement['sha256'], matches(RegExp(r'^[a-f0-9]{64}$')));
        expect(Uri.parse(supplement['source_url']).scheme, 'https');
        expect(supplement['source_locator'], isNotEmpty);
        expect(speciesTopics.containsKey(supplement['topic']), isTrue);
      }
      final catalog = jsonDecode(
        File('assets/data/species_catalog.json').readAsStringSync(),
      );
      for (final bird in catalog['species']) {
        for (final topic in speciesTopics.keys) {
          expect(
            published,
            contains((bird['id'], topic)),
            reason: "${bird['name']} · $topic",
          );
        }
      }
      final first = supplements.first;
      final topic = first['topic'];
      final id = first['species_id'];
      expect(
        store.sourcedFactsFor(id).any((f) => f['topic'] == topic),
        isFalse,
      );
      expect(
        store
            .sourcedFactsFor(id, forNotebook: true)
            .where((f) => f['topic'] == topic)
            .single['statement'],
        first['statement'],
      );
    },
  );
  testWidgets('Published card renders on a narrow mobile screen', (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final font = File('/System/Library/Fonts/Avenir Next.ttc');
    if (font.existsSync()) {
      await (FontLoader('Avenir')..addFont(
            Future.value(ByteData.sublistView(font.readAsBytesSync())),
          ))
          .load();
    }
    final icons = File(
      '/opt/homebrew/share/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    if (icons.existsSync()) {
      await (FontLoader('MaterialIcons')..addFont(
            Future.value(ByteData.sublistView(icons.readAsBytesSync())),
          ))
          .load();
    }
    final key = GlobalKey();
    final records = (snapshot['facts'] as List)
        .where((f) => f['species_id'] == 'blackbird')
        .map((f) => Map<String, dynamic>.from(f))
        .toList();
    await t.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(fontFamily: 'Avenir'),
          home: Scaffold(
            appBar: AppBar(title: const Text('Merle noir')),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: SpeciesKnowledge(facts: records),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Pour me reconnaître'), findsOneWidget);
    expect(find.textContaining('Le mâle adulte est noir'), findsOneWidget);
    expect(t.takeException(), isNull);
    if (Platform.isMacOS) {
      await t.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File(
          'docs/screenshots/sourced-species-card.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
  testWidgets(
    'Each assertion opens its own document and missing themes stay explicit',
    (t) async {
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SpeciesKnowledge(
                facts: [
                  {
                    'id': 'a',
                    'topic': 'identification',
                    'statement': 'Portrait A',
                    'source_url': 'https://example.org/a.pdf',
                    'page': 2,
                    'section': 'Description',
                    'publisher': 'Source A',
                    'document_title': 'Document A',
                  },
                  {
                    'id': 'b',
                    'topic': 'identification',
                    'statement': 'Portrait B',
                    'source_url': 'https://example.org/b',
                    'section': 'Plumage',
                    'publisher': 'Source B',
                    'document_title': 'Document B',
                  },
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.textContaining('Pépi cherche encore'), findsOneWidget);
      await t.tap(find.text('Pourquoi on le sait').first);
      await t.pumpAndSettle();
      expect(
        find.textContaining('Source A · Document A · Page 2 · Description'),
        findsOneWidget,
      );
      await t.tap(find.text('Fermer'));
      await t.pumpAndSettle();
      await t.tap(find.text('Pourquoi on le sait').last);
      await t.pumpAndSettle();
      expect(
        find.textContaining('Source B · Document B · Plumage'),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('A profile without facts does not look complete', (t) async {
    await t.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SpeciesKnowledge(facts: [])),
      ),
    );
    expect(
      find.text('Pépi prépare encore les informations de cette fiche.'),
      findsOneWidget,
    );
    expect(find.text('Pourquoi on le sait'), findsNothing);
  });
}
