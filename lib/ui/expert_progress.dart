import 'package:flutter/material.dart';

/// Reads server evidence; never derives certification from XP or an unlocked rank.
class ExpertProgressScreen extends StatefulWidget {
  final Future<List<dynamic>> Function() load;
  final Map<String, String> names;
  const ExpertProgressScreen({
    super.key,
    required this.load,
    required this.names,
  });
  @override
  State<ExpertProgressScreen> createState() => _ExpertProgressState();
}

class _ExpertProgressState extends State<ExpertProgressScreen> {
  late Future<List<dynamic>> request;
  String filter = '';
  @override
  void initState() {
    super.initState();
    request = widget.load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Mon chemin vers Expert')),
    body: FutureBuilder<List<dynamic>>(
      future: request,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Le bilan ne se charge pas. Ta progression est conservée.',
                ),
                TextButton(
                  onPressed: () => setState(() => request = widget.load()),
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final rows = snapshot.data!;
        if (rows.isEmpty) {
          return const Center(
            child: Text('Bilan indisponible pour ce compte.'),
          );
        }
        final ids = rows.map((r) => r['species_id'] as String).toSet();
        final mastered = rows.where((r) => r['mastered'] == true).length;
        final complete = ids
            .where(
              (id) => rows
                  .where((r) => r['species_id'] == id && r['mastered'] == true)
                  .map((r) => r['modality'])
                  .toSet()
                  .containsAll(['visual', 'audio', 'knowledge']),
            )
            .length;
        final shown =
            ids
                .where(
                  (id) => (widget.names[id] ?? id).toLowerCase().contains(
                    filter.toLowerCase(),
                  ),
                )
                .toList()
              ..sort(
                (a, b) =>
                    (widget.names[a] ?? a).compareTo(widget.names[b] ?? b),
              );
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              '$complete / ${ids.length} oiseaux maîtrisés',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: mastered / (ids.length * 3)),
            Text('$mastered / ${ids.length * 3} compétences validées'),
            const SizedBox(height: 12),
            const Text(
              'Chaque oiseau compte : ses photos, ses sons et ce que tu sais de lui. Les bonnes réponses sans indice doivent être variées et espacées dans le temps.',
            ),
            const Text(
              '« Contenu à compléter » concerne notre catalogue, pas ton résultat. Ce bilan ne décerne pas encore le titre Expert.',
            ),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Chercher un oiseau',
              ),
              onChanged: (v) => setState(() => filter = v),
            ),
            for (final id in shown)
              Card(
                child: ExpansionTile(
                  title: Text(widget.names[id] ?? id),
                  subtitle: Text(
                    '${rows.where((r) => r['species_id'] == id && r['mastered'] == true).length} / 3 compétences',
                  ),
                  children: [
                    for (final row in rows.where((r) => r['species_id'] == id))
                      _skill(row),
                  ],
                ),
              ),
          ],
        );
      },
    ),
  );
  Widget _skill(dynamic row) {
    final target = row['modality'] == 'audio' ? 2 : 3;
    final label =
        {
          'visual': 'Photos',
          'audio': 'Sons',
          'knowledge': 'Connaissances',
        }[row['modality']] ??
        'Compétence';
    final ready = (row['approved_references'] as num) >= target;
    final validated = row['mastered'] == true;
    return ListTile(
      leading: Icon(
        validated
            ? Icons.check_circle
            : ready
            ? Icons.school_outlined
            : Icons.hourglass_empty,
      ),
      title: Text(
        '$label · ${validated
            ? "Validée"
            : ready
            ? "En apprentissage"
            : "Contenu à compléter"}',
      ),
      subtitle: Text(
        '${row['successes']} bonnes réponses sans indice / 4 minimum\n'
        '${row['distinct_references']} références différentes / $target · ${row['sessions']} séances / 3\n'
        'Révision après 24 h : ${row['spaced_review'] == true ? "réussie" : "à faire"}\n'
        'Réponses récentes : ${row['recent_correct']} / ${row['recent_total']} · dernière ${row['latest_correct'] == true ? "réussie" : "à réussir"}',
      ),
    );
  }
}
