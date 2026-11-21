import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const ink = Color(0xff183e54),
    green = Color(0xff087a83),
    cream = Color(0xfff4fbff),
    lime = Color(0xffffd56b),
    muted = Color(0xff54717e);

class Stat extends StatelessWidget {
  final String value, label;
  const Stat({super.key, required this.value, required this.label});
  @override
  Widget build(BuildContext c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xffffefb3), Color(0xffffd777)],
      ),
      border: Border.all(color: const Color(0xffffce60)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x33182e20),
          offset: Offset(0, 4),
          blurRadius: 4,
        ),
      ],
      borderRadius: BorderRadius.circular(22),
    ),
    child: Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: green,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: ink, height: 1.35),
        ),
      ],
    ),
  );
}

/// Statistics keep their full values; large text gets a single-column layout.
class StatPair extends StatelessWidget {
  final Stat first, second;
  const StatPair({super.key, required this.first, required this.second});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 280 ||
          MediaQuery.textScalerOf(context).scale(16) > 22) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [first, const SizedBox(height: 12), second],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: first),
          const SizedBox(width: 12),
          Expanded(child: second),
        ],
      );
    },
  );
}

Future<void> openSource(BuildContext context, String url) async {
  try {
    final uri = Uri.parse(url);
    if (uri.scheme != 'https' ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw StateError('Lien indisponible');
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text(
            'Impossible d’ouvrir la source. Réessaie avec une connexion.',
          ),
        ),
      );
    }
  }
}

Future<void> sourceDialog(
  BuildContext c,
  String url,
  String publisher,
  dynamic media, {
  bool mediaOnly = false,
  List<dynamic> additionalSources = const [],
  List<dynamic> additionalMedia = const [],
}) => showDialog(
  context: c,
  builder: (context) => AlertDialog(
    title: const Text('Le carnet des sources'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!mediaOnly && additionalSources.isEmpty) ...[
            Text('Fait scientifique : $publisher'),
            TextButton(
              onPressed: () => openSource(context, url),
              child: const Text('Consulter la référence ↗'),
            ),
          ],
          for (final source in additionalSources)
            TextButton(
              onPressed: () => openSource(context, source['url']),
              child: Text('Mesures : ${source['name']} ↗'),
            ),
          for (final bird in additionalMedia)
            TextButton(
              onPressed: () => openSource(context, bird['photo']['source']),
              child: Text(
                'Photo : ${bird['name']} · ${bird['photo']['author']} · ${bird['photo']['license']} ↗',
              ),
            ),
          if (media != null) ...[
            const Divider(),
            Text(
              'Photo : ${media['author']}\n${media['license']}\n${media['modifications']}',
            ),
            TextButton(
              onPressed: () => openSource(context, media['source']),
              child: const Text('Photo originale & licence ↗'),
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Fermer'),
      ),
    ],
  ),
);
