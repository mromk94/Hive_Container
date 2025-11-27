import 'package:flutter/material.dart';

import 'services/persona_pack_store.dart';

class PersonaPackDetailScreen extends StatelessWidget {
  const PersonaPackDetailScreen({super.key, required this.pack});

  final PersonaPack pack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final json = pack.personaJson;
    final user = json['user_profile'];
    final assistant = json['assistant_persona'];
    final shared = json['shared_memory'];

    String provider = '';
    String userSummary = '';
    String assistantNotes = '';
    if (assistant is Map) {
      final pid = assistant['provider_id'];
      final notes = assistant['style_notes'];
      if (pid is String) provider = pid;
      if (notes is String) assistantNotes = notes;
    }
    if (user is Map) {
      final summary = user['summary'];
      if (summary is String) userSummary = summary;
    }

    final memories = <String>[];
    if (shared is List) {
      for (final item in shared) {
        if (item is String && item.trim().isNotEmpty) {
          memories.add(item.trim());
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(pack.name),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            if (provider.isNotEmpty)
              Text(
                'Provider: $provider',
                style: theme.textTheme.bodySmall,
              ),
            Text(
              'Created: ${pack.createdAt}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            if (userSummary.isNotEmpty) ...[
              Text(
                'User profile',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: scheme.surfaceVariant,
                ),
                child: Text(
                  userSummary,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (assistantNotes.isNotEmpty) ...[
              Text(
                'Assistant persona',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: scheme.surfaceVariant,
                ),
                child: Text(
                  assistantNotes,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (memories.isNotEmpty) ...[
              Text(
                'Shared memory (${memories.length})',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              ...memories.map(
                (m) => Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: scheme.surfaceVariant,
                  ),
                  child: Text(
                    m,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
