import 'package:flutter/material.dart';

import 'resource_tracker.dart';
import 'twin_identity.dart';

class ResourceTrackerScreen extends StatefulWidget {
  const ResourceTrackerScreen({super.key});

  @override
  State<ResourceTrackerScreen> createState() => _ResourceTrackerScreenState();
}

class _ResourceTrackerScreenState extends State<ResourceTrackerScreen> {
  ResourceSnapshot? _snapshot;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    final twin = await TwinIdentity.load();
    if (!mounted) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    setState(() {
      _snapshot = ResourceSnapshot(
        twinId: twin.twinId,
        batteryLevel: 100,
        computeCredits: 0,
        updatedAtMillis: now,
      );
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _snapshot == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Resource snapshot (Phase 6)'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final snapshot = _snapshot!;
    final updated = DateTime.fromMillisecondsSinceEpoch(snapshot.updatedAtMillis);
    final updatedStr =
        '${updated.hour.toString().padLeft(2, '0')}:${updated.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resource snapshot (Phase 6)'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Local resource view for this device only',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Values are edited manually here; real telemetry wiring will replace this later.',
            ),
            const SizedBox(height: 8),
            Text('Twin: ${snapshot.twinId}'),
            Text('Last updated: $updatedStr'),
            const SizedBox(height: 24),
            _buildSlider(
              context,
              label: 'Battery level',
              value: snapshot.batteryLevel.toDouble(),
              suffix: '%',
              min: 0,
              max: 100,
              onChanged: (v) => _update(battery: v.round()),
            ),
            const SizedBox(height: 16),
            _buildSlider(
              context,
              label: 'Compute credits',
              value: snapshot.computeCredits.toDouble(),
              suffix: '',
              min: 0,
              max: 1000,
              onChanged: (v) => _update(credits: v.round()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlider(
    BuildContext context, {
    required String label,
    required double value,
    required String suffix,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    final clamped = value.clamp(min, max);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyLarge),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: clamped,
                min: min,
                max: max,
                onChanged: onChanged,
              ),
            ),
            const SizedBox(width: 8),
            Text('${clamped.round()}$suffix'),
          ],
        ),
      ],
    );
  }

  void _update({int? battery, int? credits}) {
    final current = _snapshot;
    if (current == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    setState(() {
      _snapshot = ResourceSnapshot(
        twinId: current.twinId,
        batteryLevel: battery ?? current.batteryLevel,
        computeCredits: credits ?? current.computeCredits,
        updatedAtMillis: now,
      );
    });
  }
}
