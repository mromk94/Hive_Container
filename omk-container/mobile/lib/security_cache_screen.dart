import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'security_memory_db.dart';

final securityCacheProvider = FutureProvider<List<SecurityMemoryEntry>>((ref) async {
  final db = await SecurityMemoryDb.open();
  return db.listRecent(limit: 100);
});

class SecurityCacheScreen extends ConsumerWidget {
  const SecurityCacheScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncEntries = ref.watch(securityCacheProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Security cache'),
      ),
      body: asyncEntries.when(
        data: (entries) {
          if (entries.isEmpty) {
            return const Center(child: Text('No cached verdicts yet.'));
          }
          return ListView.builder(
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final e = entries[index];
              return ListTile(
                title: Text('${e.host} (${e.verdict})'),
                subtitle: Text('risk=${e.riskScore.toStringAsFixed(2)} • source=${e.source}'),
                trailing: IconButton(
                  icon: Icon(e.pinned ? Icons.push_pin : Icons.push_pin_outlined),
                  onPressed: () async {
                    final db = await SecurityMemoryDb.open();
                    await db.setPinned(e.id!, !e.pinned);
                    ref.refresh(securityCacheProvider);
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => ref.refresh(securityCacheProvider),
                child: const Text('Refresh'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed: () async {
                  final db = await SecurityMemoryDb.open();
                  await db.purgeAll();
                  // ignore: use_build_context_synchronously
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cache purged.')),
                  );
                  ref.refresh(securityCacheProvider);
                },
                child: const Text('Purge'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
