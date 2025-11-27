/// Shadow model manifest for minimal local LLM backups.
class ShadowModelManifest {
  ShadowModelManifest({
    required this.id,
    required this.sizeBytes,
    required this.capabilities,
  });

  final String id;
  final int sizeBytes;
  final List<String> capabilities;
}
