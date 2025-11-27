import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n.dart';
import 'permissions_screen.dart';
import 'security_cache_screen.dart';
import 'state.dart';
import 'consciousness_registry.dart';
import 'twin_status_screen.dart';
import 'ar_debug_screen.dart';
import 'community_board_screen.dart';
import 'knowledge_pool_screen.dart';
import 'event_tags_screen.dart';
import 'learning_pulse_screen.dart';
import 'community_milestones_screen.dart';
import 'ai_villages_screen.dart';
import 'resource_tracker_screen.dart';
import 'sync_policy_screen.dart';
import 'topology_screen.dart';
import 'persona_manager_screen.dart';
import 'wallet_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = Strings.of(context);
    final floating = ref.watch(floatingEnabledProvider);
    final ttl = ref.watch(securityTtlMinutesProvider);
    final model = ref.watch(selectedModelProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.settingsTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile.adaptive(
            value: floating,
            onChanged: (v) =>
                ref.read(floatingEnabledProvider.notifier).state = v,
            title: Text(strings.toggleFloating),
            subtitle: const Text(
              'Show a small assistant bubble above content in this debug build.',
            ),
          ),
          const SizedBox(height: 16),
          Text(
            strings.privacySection,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ListTile(
            title: Text(strings.historyPurge),
            subtitle: const Text(
              'Clear local mini chat history and recent assistant messages.',
            ),
            trailing: ElevatedButton(
              onPressed: () {
                ref.read(miniChatProvider.notifier).clearHistory();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('History cleared (mock).')),
                );
              },
              child: const Text('Clear'),
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            title: const Text('Persona packs'),
            subtitle: const Text(
              'Manage imported AI consciousness packs created from conversations.',
            ),
            trailing: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PersonaManagerScreen(),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            title: Text(strings.ttlLabel),
            subtitle: Slider(
              min: 5,
              max: 120,
              divisions: 23,
              label: ttl.toString(),
              value: ttl.toDouble(),
              onChanged: (v) => ref
                  .read(securityTtlMinutesProvider.notifier)
                  .state = v.round(),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            strings.modelSelection,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ListTile(
            title: const Text('OMK Wallet'),
            subtitle: const Text(
              'View your OMK balance and future transaction history.',
            ),
            trailing: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const WalletScreen(),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: model,
            items: const [
              DropdownMenuItem(value: 'gemini', child: Text('Gemini (cloud)')),
              DropdownMenuItem(value: 'openai', child: Text('OpenAI (cloud)')),
              DropdownMenuItem(value: 'local', child: Text('Local / TFLite (mock)')),
            ],
            onChanged: (v) async {
              if (v == null) return;
              ref.read(selectedModelProvider.notifier).state = v;
              // Keep the consciousness registry in sync with Settings.
              try {
                final reg = await ConsciousnessRegistryStore.load();
                ConsciousnessProviderId? id;
                switch (v) {
                  case 'openai':
                    id = ConsciousnessProviderId.openai;
                    break;
                  case 'gemini':
                    id = ConsciousnessProviderId.gemini;
                    break;
                  case 'local':
                    id = ConsciousnessProviderId.local;
                    break;
                  default:
                    id = null;
                }
                if (id != null) {
                  reg.active = id;
                  await ConsciousnessRegistryStore.save(reg);
                }
              } catch (_) {}
            },
          ),
          const SizedBox(height: 24),
          ListTile(
            title: const Text('Security cache'),
            subtitle: const Text(
              'View cached URL verdicts, pin important entries, and purge local cache.',
            ),
            trailing: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const SecurityCacheScreen(),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            title: const Text('AR / Realm debug'),
            subtitle: const Text(
              'Inspect logical AR realm scene, mesh health, and simulate AR/twin intents.',
            ),
            trailing: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ArDebugScreen(),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            title: const Text('Community board (Phase 6)'),
            subtitle: const Text(
              'Experiment with a local micro-community feed before mesh/cloud sync.',
            ),
            trailing: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const CommunityBoardScreen(),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            title: const Text('Knowledge pool (Phase 6)'),
            subtitle: const Text(
              'Inspect and seed local shared facts for this node only.',
            ),
            trailing: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const KnowledgePoolScreen(),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            title: const Text('Event tags (Phase 6)'),
            subtitle: const Text(
              'Create and inspect local event annotations in memory.',
            ),
            trailing: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const EventTagsScreen(),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            title: const Text('Learning pulses (Phase 6)'),
            subtitle: const Text(
              'Start and complete local learning cycles (no scheduling yet).',
            ),
            trailing: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const LearningPulseScreen(),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            title: const Text('Community milestones (Phase 6)'),
            subtitle: const Text(
              'View and tweak local community metrics for this node.',
            ),
            trailing: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const CommunityMilestonesScreen(),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            title: const Text('AI villages (Phase 6)'),
            subtitle: const Text(
              'Inspect mock clusters of OMK nodes per region (no map yet).',
            ),
            trailing: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AiVillagesScreen(),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            title: const Text('Resource snapshot (Phase 6)'),
            subtitle: const Text(
              'Manually tweak local resource metrics for this node only.',
            ),
            trailing: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ResourceTrackerScreen(),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            title: const Text('Sync policy (Phase 7)'),
            subtitle: const Text(
              'Inspect memory sync intervals and current packet scheduling hints.',
            ),
            trailing: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const SyncPolicyScreen(),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            title: const Text('Topology (Phase 7)'),
            subtitle: const Text(
              'View a simple topology snapshot derived from current mesh peers.',
            ),
            trailing: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const TopologyScreen(),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            title: const Text('Twin status'),
            subtitle: const Text(
              'Inspect your local TwinSnapshot and routing preferences (Phase 3 debug).',
            ),
            trailing: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const TwinStatusScreen(),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            title: Text(strings.permissionsTitle),
            subtitle: const Text(
              'Review why OMK asks for each permission and simulate approvals.',
            ),
            trailing: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PermissionsScreen(),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ],
      ),
    );
  }
}
