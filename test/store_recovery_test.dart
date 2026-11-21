import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:petit_ornitho/data/game_store.dart';

class LocalStore extends GameStore {
  String profile = 'guest';
  LocalStore(super.prefs, super.content, super.media, {super.persist});
  @override
  String get identity => profile;
}

void main() {
  final content =
      jsonDecode(File('assets/data/content.json').readAsStringSync())
          as Map<String, dynamic>;
  test(
    'Le bilan conserve les espèces, la première réponse et les aides après reprise',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = LocalStore(await SharedPreferences.getInstance(), {
        ...content,
        'species': jsonDecode(
          File('assets/data/species_catalog.json').readAsStringSync(),
        )['species'],
      }, [])..reload();
      await store.start(1);
      final rows = <Map<String, dynamic>>[];
      Map<String, dynamic>? result;
      while (store.active != null) {
        final i = rows.length;
        final q = store.current;
        if (i == 1) await store.registerGuideHint();
        final name = store.species.firstWhere(
          (b) => b['id'] == q.species,
        )['name'];
        rows.add({'name': name, 'correct': i != 0, 'assisted': i == 1});
        await store.answer(
          i == 0 ? (q.answer + 1) % q.options.length : q.answer,
        );
        result = await store.next();
        store.reload();
      }
      expect(result!['recap'], rows);
      expect(store.state['last']['recap'], rows);
    },
  );
  test(
    'Pépi assistance survives reload and resets on the next question',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = LocalStore(prefs, content, [])..reload();
      await store.start(1);
      await store.registerGuideHint();
      store.reload();
      expect(store.active!['assisted'], true);
      await store.answer(store.current.answer);
      expect(store.attempts.last['assisted'], true);
      await store.next();
      expect(store.active!['assisted'], isNull);
      await store.answer(store.current.answer);
      expect(store.attempts.last['assisted'], false);
    },
  );
  test(
    'failed completion write retries without double XP or losing the question',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      bool fail = false;
      final store = LocalStore(
        prefs,
        content,
        [],
        persist: (key, value) async =>
            fail ? false : prefs.setString(key, value),
      );
      store.reload();
      await store.start(1);
      for (var i = 0; i < 5; i++) {
        await store.answer(store.current.answer);
        await store.next();
      }
      await store.answer(store.current.answer);
      final before = jsonEncode(store.state);
      fail = true;
      await expectLater(store.next(), throwsStateError);
      expect(jsonEncode(store.state), before);
      expect(store.xp, 0);
      fail = false;
      await store.next();
      expect(store.xp, 90);
      expect(store.completed, 1);
      await store.next();
      expect(store.xp, 90);
      store.reload();
      expect(store.xp, 90);
      expect(store.unlocked, 1);
    },
  );
  test(
    'pending save cannot apply old profile state to a new profile',
    () async {
      SharedPreferences.setMockInitialValues({
        'ornitho_v1_other': jsonEncode({'xp': 12}),
      });
      final prefs = await SharedPreferences.getInstance();
      final completed = Completer<bool>();
      String? writtenKey;
      final store = LocalStore(
        prefs,
        content,
        [],
        persist: (key, value) {
          writtenKey = key;
          return completed.future;
        },
      );
      store.reload();
      store.state = {'xp': 90};
      final pending = store.save();
      store.profile = 'other';
      store.reload();
      completed.complete(true);
      await expectLater(pending, throwsStateError);
      expect(writtenKey, 'ornitho_v1_guest');
      expect(store.xp, 12);
    },
  );
  test(
    'locked levels, switching an active journey and extra hints are rejected',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = LocalStore(
        await SharedPreferences.getInstance(),
        content,
        [],
      );
      store.reload();
      await expectLater(store.start(2), throwsStateError);
      await store.start(1);
      store.state['unlocked'] = 2;
      await expectLater(store.start(2), throwsStateError);
      expect(store.active!['level'], 1);
      final q = store.questions.firstWhere((q) => q.kind == 'mystery');
      store.state['active'] = {
        'id': 'test',
        'ids': [q.id],
        'index': 0,
        'hints': 1,
        'level': 1,
        'score': 0,
        'answers': [],
      };
      for (var i = 0; i < 6; i++) {
        await store.hint();
      }
      expect(store.active!['hints'], q.clues.length);
      await store.answer(q.answer);
      await store.hint();
      expect(store.active!['hints'], q.clues.length);
    },
  );
}
