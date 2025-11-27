/// Logical models for a local mesh certificate authority. This file does
/// not implement real cryptography; it defines the shapes that native
/// crypto backends will populate.
class MeshCertificate {
  MeshCertificate({
    required this.certId,
    required this.subjectNodeId,
    required this.issuerId,
    required this.validFromMillis,
    required this.validToMillis,
    required this.capabilities,
    required this.signature,
  });

  final String certId;
  final String subjectNodeId;
  final String issuerId;
  final int validFromMillis;
  final int validToMillis;
  final List<String> capabilities;
  final String signature;
}

class LocalMeshCAState {
  LocalMeshCAState({
    required this.caId,
    required this.currentCert,
  });

  final String caId;
  final MeshCertificate currentCert;
}
