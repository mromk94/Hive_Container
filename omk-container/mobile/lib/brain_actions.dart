/// Catalog of high-level actions the imported LLM brain can request
/// inside OMK Container. In future builds this will map to concrete
/// function-call endpoints.
class BrainActionDescriptor {
  BrainActionDescriptor({
    required this.id,
    required this.label,
    required this.description,
  });

  final String id;
  final String label;
  final String description;
}

class BrainActionCatalog {
  static final List<BrainActionDescriptor> actions = [
    BrainActionDescriptor(
      id: 'analyze_context',
      label: 'Analyze current context',
      description:
          'Run OMK security context analysis using CCE snapshot + chat to assess risk.',
    ),
    BrainActionDescriptor(
      id: 'sync_memory',
      label: 'Sync security memory',
      description:
          'Trigger a best-effort memory sync to Hive Bridge using current SyncPolicy.',
    ),
    BrainActionDescriptor(
      id: 'mesh_broadcast_note',
      label: 'Broadcast mesh note',
      description:
          'Emit a TimeSyncedSnapshot or MeshEvent to nearby peers via mesh transport.',
    ),
    BrainActionDescriptor(
      id: 'ar_realm_hint',
      label: 'AR realm hint',
      description:
          'Propose an AR/twin overlay change for the current logical realm.',
    ),
    BrainActionDescriptor(
      id: 'community_post',
      label: 'Community board post',
      description:
          'Draft a post into the local community board / knowledge pool.',
    ),
  ];
}
