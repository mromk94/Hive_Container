import 'package:flutter/material.dart';

import 'knowledge_pool.dart';
import 'twin_identity.dart';

class KnowledgePoolScreen extends StatefulWidget {
  const KnowledgePoolScreen({super.key});

  @override
  State<KnowledgePoolScreen> createState() => _KnowledgePoolScreenState();
}

class _KnowledgePoolScreenState extends State<KnowledgePoolScreen> {
  final KnowledgePool _pool = KnowledgePool();
  final TextEditingController _keyController = TextEditingController();
  final TextEditingController _summaryController = TextEditingController();
  TwinIdentity? _twin;
  bool _loading = true;
  String _activeKey = '';

  @override
  void initState() {
    super.initState();
    _loadTwin();
  }

  Future<void> _loadTwin() async {
    final twin = await TwinIdentity.load();
    if (!mounted) return;
    setState(() {
      _twin = twin;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _keyController.dispose();
    _summaryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final key = _activeKey.trim();
    final items = key.isEmpty ? const <KnowledgeItem>[] : _pool.forKey(key);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Knowledge pool (debug)'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Local knowledge items',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      const Text(
                        'This view uses an in-memory KnowledgePool only (no mesh/cloud sync yet).',
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _keyController,
                          decoration: const InputDecoration(
                            hintText: 'Key (e.g. url_hash, topic)',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _activeKey = _keyController.text;
                          });
                        },
                        child: const Text('Load'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final ts = DateTime.fromMillisecondsSinceEpoch(
                        item.createdAtMillis,
                      );
                      final time =
                          '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}';
                      return ListTile(
                        title: Text(item.summary),
                        subtitle: Text(
                          '${item.key} • ${item.sourceTwinId} • $time',
                        ),
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Seed new knowledge item for this node'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _summaryController,
                        decoration: const InputDecoration(
                          hintText: 'Short summary to store',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          onPressed: _twin == null || _keyController.text.trim().isEmpty
                              ? null
                              : _onAdd,
                          child: const Text('Add'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  void _onAdd() {
    final key = _keyController.text.trim();
    final summary = _summaryController.text.trim();
    final twin = _twin;
    if (key.isEmpty || summary.isEmpty || twin == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final item = KnowledgeItem(
      id: 'k-$now',
      key: key,
      summary: summary,
      createdAtMillis: now,
      sourceTwinId: twin.twinId,
    );
    _pool.add(item);
    _summaryController.clear();
    setState(() {
      _activeKey = key;
    });
  }
}
