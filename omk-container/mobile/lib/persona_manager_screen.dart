import 'package:flutter/material.dart';

import 'services/persona_pack_store.dart';
import 'persona_pack_detail_screen.dart';

class PersonaManagerScreen extends StatefulWidget {
  const PersonaManagerScreen({super.key});

  @override
  State<PersonaManagerScreen> createState() => _PersonaManagerScreenState();
}

class _PersonaManagerScreenState extends State<PersonaManagerScreen> {
  List<PersonaPack>? _packs;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final packs = await PersonaPackStore.instance.loadAll();
      if (!mounted) return;
      setState(() {
        _packs = packs;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _toggleActive(PersonaPack pack, bool active) async {
    await PersonaPackStore.instance.setActive(pack.id, active);
    await _load();
  }

  Future<void> _deletePack(PersonaPack pack) async {
    await PersonaPackStore.instance.delete(pack.id);
    await _load();
  }

  Future<void> _renamePack(PersonaPack pack) async {
    final controller = TextEditingController(text: pack.name);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Rename persona pack'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Name',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                if (value.isEmpty) {
                  return;
                }
                Navigator.of(context).pop(value);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    if (result == null || result.trim().isEmpty) {
      return;
    }
    final updated = pack.copyWith(name: result.trim());
    await PersonaPackStore.instance.save(updated);
    await _load();
  }

  void _openDetails(PersonaPack pack) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PersonaPackDetailScreen(pack: pack),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final packs = _packs;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Persona packs'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _error!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : (packs == null || packs.isEmpty)
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'No imported personas yet. Use "Import by conversation" to create your first pack.',
                          style: theme.textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: packs.length,
                        itemBuilder: (context, index) {
                          final pack = packs[index];
                          final json = pack.personaJson;
                          String provider = '';
                          final assistant = json['assistant_persona'];
                          if (assistant is Map) {
                            final pid = assistant['provider_id'];
                            if (pid is String) {
                              provider = pid;
                            }
                          }
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: ListTile(
                              onTap: () => _openDetails(pack),
                              title: Text(pack.name),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Switch(
                                    value: pack.active,
                                    onChanged: (v) => _toggleActive(pack, v),
                                  ),
                                  IconButton(
                                    tooltip: 'Delete',
                                    onPressed: () => _deletePack(pack),
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
