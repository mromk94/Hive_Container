import 'package:flutter/material.dart';

import 'learning_pulse.dart';
import 'twin_identity.dart';

class LearningPulseScreen extends StatefulWidget {
  const LearningPulseScreen({super.key});

  @override
  State<LearningPulseScreen> createState() => _LearningPulseScreenState();
}

class _LearningPulseScreenState extends State<LearningPulseScreen> {
  final List<LearningPulseCycle> _cycles = <LearningPulseCycle>[];
  TwinIdentity? _twin;
  bool _loading = true;

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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Learning pulses (Phase 6)'),
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
                      Text('Local learning pulse cycles',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      const Text(
                        'Cycles are in-memory only and not yet scheduled or shared.',
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    itemCount: _cycles.length,
                    itemBuilder: (context, index) {
                      final cycle = _cycles[_cycles.length - 1 - index];
                      final started =
                          DateTime.fromMillisecondsSinceEpoch(cycle.startedAtMillis);
                      final startedStr =
                          '${started.hour.toString().padLeft(2, '0')}:${started.minute.toString().padLeft(2, '0')}';
                      final completed = cycle.completedAtMillis == null
                          ? null
                          : DateTime.fromMillisecondsSinceEpoch(
                              cycle.completedAtMillis!,
                            );
                      final completedStr = completed == null
                          ? 'active'
                          : '${completed.hour.toString().padLeft(2, '0')}:${completed.minute.toString().padLeft(2, '0')}';
                      final participants = cycle.participantTwinIds.join(', ');
                      return ListTile(
                        title: Text('Cycle ${cycle.id}'),
                        subtitle: Text(
                          'Started: $startedStr • Completed: $completedStr\nParticipants: $participants',
                        ),
                        trailing: cycle.completedAtMillis == null
                            ? IconButton(
                                icon: const Icon(Icons.check_circle_outline),
                                onPressed: () => _complete(cycle),
                              )
                            : const Icon(Icons.check_circle, color: Colors.green),
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: _twin == null ? null : _startNew,
                      child: const Text('Start new pulse'),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  void _startNew() {
    final twin = _twin;
    if (twin == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final cycle = LearningPulseCycle(
      id: 'lp-$now',
      startedAtMillis: now,
      completedAtMillis: null,
      participantTwinIds: <String>[twin.twinId],
    );
    setState(() {
      _cycles.add(cycle);
    });
  }

  void _complete(LearningPulseCycle cycle) {
    final idx = _cycles.indexOf(cycle);
    if (idx < 0) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    setState(() {
      _cycles[idx] = LearningPulseCycle(
        id: cycle.id,
        startedAtMillis: cycle.startedAtMillis,
        completedAtMillis: now,
        participantTwinIds: cycle.participantTwinIds,
      );
    });
  }
}
