import 'package:flutter/material.dart';
import '../data/game_store.dart';

Future<void> reportContent(
  BuildContext context,
  GameStore store, {
  required String speciesId,
  String? questionId,
  int? version,
  String? photo,
}) async {
  final sent = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ContentReportDialog(
      title: questionId == null ? 'Signaler cette photo' : 'Signaler cette question',
      send: (comment) async {
        await store.submitContentReport(
          speciesId: speciesId,
          questionId: questionId,
          version: version,
          photo: photo,
          comment: comment,
        );
      },
    ),
  );
  if (sent == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Signalement envoyé. Merci !')),
    );
  }
}

class ContentReportDialog extends StatefulWidget {
  const ContentReportDialog({
    super.key,
    required this.title,
    required this.send,
  });
  final String title;
  final Future<void> Function(String) send;
  @override
  State<ContentReportDialog> createState() => _ContentReportDialogState();
}

class _ContentReportDialogState extends State<ContentReportDialog> {
  String comment = '';
  bool sending = false, failed = false;

  Future<void> submit() async {
    if (sending || comment.trim().isEmpty) return;
    setState(() {
      sending = true;
      failed = false;
    });
    try {
      await widget.send(comment.trim());
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          sending = false;
          failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !sending,
    child: AlertDialog(
      title: Text(widget.title),
      scrollable: true,
      content: TextField(
        enabled: !sending,
        maxLength: 1000,
        minLines: 2,
        maxLines: 4,
        decoration: InputDecoration(
          labelText: 'Que souhaites-tu signaler ?',
          errorText: failed ? 'Envoi impossible. Réessaie.' : null,
        ),
        onChanged: (value) => setState(() => comment = value),
      ),
      actions: [
        TextButton(
          onPressed: sending ? null : () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: sending || comment.trim().isEmpty ? null : submit,
          child: Text(sending ? 'Envoi…' : 'Envoyer'),
        ),
      ],
    ),
  );
}
