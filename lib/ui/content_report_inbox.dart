import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ContentReportInbox extends StatefulWidget {
  final SupabaseClient client;
  const ContentReportInbox({required this.client, super.key});

  @override
  State<ContentReportInbox> createState() => _ContentReportInboxState();
}

class _ContentReportInboxState extends State<ContentReportInbox> {
  List<Map<String, dynamic>> reports = [];
  bool busy = true;
  String? error;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    setState(() {
      busy = true;
      error = null;
      reports = [];
    });
    try {
      final rows = await widget.client.rpc('list_content_reports');
      if (mounted) {
        setState(() => reports = List<Map<String, dynamic>>.from(rows as List));
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Liste indisponible. Vérifiez la connexion et vos droits de relecture.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> review(String id, String status) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.client.rpc(
        'review_content_report',
        params: {'p_id': id, 'p_status': status},
      );
      if (mounted) await refresh();
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          error = 'Impossible de confirmer la décision. Actualisez la liste.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Signalements à vérifier'),
      actions: [
        IconButton(
          onPressed: busy ? null : refresh,
          icon: const Icon(Icons.refresh),
          tooltip: 'Actualiser',
        ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (busy) const LinearProgressIndicator(),
            if (error != null) Text(error!),
            if (!busy && error == null && reports.isEmpty)
              const Text('Aucun signalement en attente.'),
            for (final row in reports)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row['question_id'] == null
                            ? 'Photo signalée'
                            : 'Question signalée',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (DateTime.tryParse('${row['created_at']}')?.toLocal()
                          case final DateTime date)
                        Text(
                          MaterialLocalizations.of(
                            context,
                          ).formatFullDate(date),
                        ),
                      if (row['comment'] case final String comment)
                        SelectableText(comment),
                      if (row['question_id'] != null)
                        SelectableText(
                          'Question : ${row['question_id']}${row['question_version'] == null ? '' : ' · version ${row['question_version']}'}',
                        ),
                      if (row['species_id'] != null)
                        SelectableText('Espèce : ${row['species_id']}'),
                      if (row['photo_ref'] != null)
                        SelectableText('Photo : ${row['photo_ref']}'),
                      Wrap(
                        spacing: 8,
                        children: [
                          FilledButton.tonal(
                            onPressed: busy
                                ? null
                                : () => review(row['id'] as String, 'resolved'),
                            child: const Text('Marquer comme résolu'),
                          ),
                          TextButton(
                            onPressed: busy
                                ? null
                                : () =>
                                      review(row['id'] as String, 'dismissed'),
                            child: const Text('Classer sans suite'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
