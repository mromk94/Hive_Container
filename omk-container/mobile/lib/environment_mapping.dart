/// Logical representation of AR environment primitives detected by
/// ARCore/ARKit. Platform plugins will map native types into these.
class PlaneSurface {
  PlaneSurface({
    required this.id,
    required this.widthMeters,
    required this.heightMeters,
  });

  final String id;
  final double widthMeters;
  final double heightMeters;
}

class EnvironmentMap {
  EnvironmentMap({
    required this.planes,
  });

  final List<PlaneSurface> planes;
}
