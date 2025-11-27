import 'package:flutter/material.dart';

import 'services/persona_pack_store.dart';

class PersonaSummaryScreen extends StatefulWidget {
  const PersonaSummaryScreen({super.key, required this.draft});

  final PersonaPack draft;

  @override
  State<PersonaSummaryScreen> createState() => _PersonaSummaryScreenState();
}

class _PersonaSummaryScreenState extends State<PersonaSummaryScreen> {
  late final TextEditingController _nameController;
  late bool _active;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.draft.name);
    _active = widget.draft.active;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _error = 'Give this persona a name.';
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = widget.draft.copyWith(name: name, active: _active);
      await PersonaPackStore.instance.save(updated);
      if (!mounted) return;
      Navigator.of(context).pop(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _active
                ? 'Persona pack saved and activated for this device.'
                : 'Persona pack saved on this device.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final pack = widget.draft;
    final json = pack.personaJson;
    final user = json['user_profile'];
    final assistant = json['assistant_persona'];
    final shared = json['shared_memory'];

    String userSummary = '';
    if (user is Map) {
      final summary = user['summary'];
      if (summary is String) userSummary = summary;
    }

    String assistantNotes = '';
    String provider = '';
    if (assistant is Map) {
      final notes = assistant['style_notes'];
      final pid = assistant['provider_id'];
      if (notes is String) assistantNotes = notes;
      if (pid is String) provider = pid;
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
        title: const Text('Persona summary'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Persona name',
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Switch(
                  value: _active,
                  onChanged: (v) {
                    setState(() {
                      _active = v;
                    });
                  },
                ),
                const SizedBox(width: 8),
                Text(
                  _active ? 'Activate now' : 'Keep inactive for now',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
            if (provider.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Source provider: $provider',
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  if (userSummary.isNotEmpty) ...[
                    Text(
                      'User profile',
                      style: theme.textTheme.titleSmall,
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
                      style: theme.textTheme.titleSmall,
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
                      style: theme.textTheme.titleSmall,
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
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
              ),
            ],
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_saving ? 'Saving…' : 'Save persona pack'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
