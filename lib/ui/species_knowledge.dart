import 'package:flutter/material.dart';
import 'components.dart';

const speciesTopics = {
  'identification': 'Pour me reconnaître',
  'habitat': 'Où me trouver ?',
  'diet': 'À mon menu',
  'breeding': 'Mon nid et mes petits',
  'migration': 'Mes voyages',
  'behaviour': 'Mes petites habitudes',
};

/// One source per displayed assertion; never attributes the whole card to a
/// single document. An absent topic is not a completed or reviewed section.
class SpeciesKnowledge extends StatelessWidget {
  final List<Map<String, dynamic>> facts;
  const SpeciesKnowledge({super.key, required this.facts});

  @override
  Widget build(BuildContext context) {
    final missing = speciesTopics.keys
        .where((topic) => !facts.any((f) => f['topic'] == topic))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        const Text(
          'Le carnet de cet oiseau',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: ink,
          ),
        ),
        if (facts.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Pépi prépare encore les informations de cette fiche.'),
          ),
        for (final topic in speciesTopics.entries)
          if (facts.any((f) => f['topic'] == topic.key))
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 12),
              expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
              initiallyExpanded: topic.key == 'identification',
              title: Text(
                topic.value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
              children: [
                for (final fact in facts.where((f) => f['topic'] == topic.key))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fact['statement'],
                          style: const TextStyle(height: 1.5),
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(padding: EdgeInsets.zero),
                          icon: const Icon(Icons.menu_book_outlined, size: 18),
                          label: const Text('Pourquoi on le sait'),
                          onPressed: () {
                            final uri = Uri.parse(fact['source_url']);
                            final url = fact['page'] == null
                                ? uri.toString()
                                : uri
                                      .replace(fragment: 'page=${fact['page']}')
                                      .toString();
                            sourceDialog(
                              context,
                              url,
                              [
                                fact['publisher'],
                                fact['document_title'],
                                if (fact['page'] != null)
                                  'Page ${fact['page']}',
                                if (fact['section'] != null) fact['section'],
                              ].whereType<String>().join(' · '),
                              null,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
              ],
            ),
        if (missing.isNotEmpty && facts.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Pépi cherche encore : ${missing.map((t) => speciesTopics[t]!.toLowerCase()).join(' · ')}.',
              style: const TextStyle(color: muted, height: 1.4),
            ),
          ),
      ],
    );
  }
}
