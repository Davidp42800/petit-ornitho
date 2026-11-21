import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'package:petit_ornitho/data/game_store.dart';
import 'package:petit_ornitho/domain/decisive_criterion.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'bundled guest journey unlocks and completes all five stages',
    () async {
      SharedPreferences.setMockInitialValues({});
      dynamic read(String file) =>
          jsonDecode(File('assets/data/$file.json').readAsStringSync());
      final content = read('content') as Map<String, dynamic>;
      content['recordings'] = read('recordings');
      content['questions'].addAll(read('journey_questions'));
      final store = GuestJourneyStore(
        await SharedPreferences.getInstance(),
        content,
        read('media'),
        learningRules: read('learning_rules'),
        speciesCatalog: read('species_catalog'),
        progression: read('progression'),
        publishedFacts: read('published_species_facts')['facts'],
        knowledgeCatalog: read('knowledge_catalog'),
        photoCatalog: read('photo_catalog'),
      )..reload();
      for (int stage = 1; stage <= 5; stage++) {
        var sessions = 0;
        do {
          await store.start(stage);
          final count = (store.active!['ids'] as List).length;
          for (int i = 0; i < count; i++) {
            final q = store.current;
            if (q.data['format'] == 'decisive_criterion') {
              await store.answerCriterion(
                CriterionPhase.identification,
                q.answer,
              );
              await store.answerCriterion(
                CriterionPhase.justification,
                q.data['justification']['answer'],
              );
            } else {
              await store.answer(q.answer);
            }
            await store.next();
          }
          expect(store.active, isNull);
          sessions++;
        } while (stage < 5 && store.unlocked == stage && sessions < 80);
        expect(
          store.unlocked,
          stage == 5 ? 5 : stage + 1,
          reason:
              'Stage $stage after $sessions sessions: ${store.chapterProgress(stage).counts}',
        );
      }
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );
}

class GuestJourneyStore extends GameStore {
  GuestJourneyStore(
    super.prefs,
    super.content,
    super.media, {
    super.learningRules,
    super.speciesCatalog,
    super.progression,
    super.publishedFacts,
    super.knowledgeCatalog,
    super.photoCatalog,
  });
  @override
  String get identity => 'guest';
  @override
  Future<void> syncQuestionWithdrawals() async {}
}
