import 'package:flutter_test/flutter_test.dart';
import 'package:petit_ornitho/domain/chapter_progress.dart';

void main() {
  List<Map<String, dynamic>> attempts(int sessions) => [
    for (var session = 0; session < sessions; session++)
      for (var i = 0; i < 6; i++)
        {
          'id': '$session:$i',
          'session_id': '$session',
          'protocol': 2,
          'stage': 1,
          'target_species': 'bird$i',
          'correct': true,
          'assisted': false,
          'modality': i.isEven ? 'visual' : 'knowledge',
          'reference': '$session:$i',
        },
  ];
  List<Map<String, dynamic>> sessions(int n) => [
    for (var i = 0; i < n; i++) {'id': '$i', 'stage': 1, 'total': 6},
  ];
  test('One perfect series cannot unlock; three varied series can', () {
    expect(ChapterProgress.evaluate(1, attempts(1), sessions(1)).ready, false);
    expect(ChapterProgress.evaluate(1, attempts(3), sessions(3)).ready, true);
  });
  test(
    'Assisted, incomplete, duplicate and other-stage attempts cannot inflate objectives',
    () {
      final data = attempts(3);
      data[0]['assisted'] = true;
      data[1]['assisted'] = true;
      final result = ChapterProgress.evaluate(1, [
        ...data,
        ...data,
      ], sessions(3));
      expect(result.counts['sessions'], 2);
      expect(result.counts['correct'], 16);
      expect(result.ready, false);
      expect(
        ChapterProgress.evaluate(2, data, sessions(3)).counts['correct'],
        0,
      );
      expect(ChapterProgress.evaluate(1, data, []).counts['correct'], 0);
    },
  );
  test(
    'No audio means no water chapter validation; stage five is not certification',
    () {
      final data = attempts(6).map((a) => {...a, 'stage': 2}).toList();
      final done = sessions(6).map((s) => {...s, 'stage': 2}).toList();
      expect(ChapterProgress.evaluate(2, data, done).ready, false);
      expect(ChapterProgress.evaluate(5, data, done).ready, false);
    },
  );
}
